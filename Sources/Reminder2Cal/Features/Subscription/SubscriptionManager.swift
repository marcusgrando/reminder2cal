import Foundation
import StoreKit

/// Product identifiers for subscriptions
enum SubscriptionProduct: String, CaseIterable {
    case annual = "com.marcusgrando.Reminder2Cal.annual"
}

/// Manages subscriptions and trial period
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var isTrialActive: Bool = false
    @Published private(set) var trialDaysRemaining: Int = 0
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseError: String?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var productLoadError: String?
    @Published private(set) var subscriptionExpirationDate: Date?

    // MARK: - Private Properties

    private let trialDurationDays: Int = 7
    private let firstLaunchKey = "com.marcusgrando.Reminder2Cal.firstLaunchDate"
    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Computed Properties

    /// Returns true if user has access (subscribed or in trial)
    var hasAccess: Bool {
        isSubscribed || isTrialActive
    }

    var trialEndDate: Date? {
        guard let firstLaunch = firstLaunchDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: trialDurationDays, to: firstLaunch)
    }

    private var firstLaunchDate: Date? {
        get {
            UserDefaults.standard.object(forKey: firstLaunchKey) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: firstLaunchKey)
        }
    }
    
    /// Status text for display
    var statusText: String {
        if isSubscribed {
            if let expDate = subscriptionExpirationDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return "Subscribed until \(formatter.string(from: expDate))"
            }
            return "Subscribed"
        } else if isTrialActive {
            return "Trial: \(trialDaysRemaining) days left"
        } else {
            return "Trial ended"
        }
    }

    // MARK: - Initialization

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await updateSubscriptionStatus()
            updateTrialStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Public Methods

    /// Check and update all status
    func refreshStatus() async {
        await updateSubscriptionStatus()
        updateTrialStatus()
    }

    /// Purchase a subscription
    func purchase(_ product: Product) async throws {
        isLoading = true
        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                
                // Update status immediately
                isSubscribed = true
                if let expirationDate = transaction.expirationDate {
                    subscriptionExpirationDate = expirationDate
                }

            case .userCancelled:
                break

            case .pending:
                purchaseError = "Purchase is pending approval"

            @unknown default:
                purchaseError = "Unknown purchase result"
            }
        } catch {
            purchaseError = error.localizedDescription
            throw error
        }

        isLoading = false
    }

    /// Restore previous purchases
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil

        do {
            try await AppStore.sync()
            await updateSubscriptionStatus()
            
            if !isSubscribed {
                purchaseError = "No active subscription found"
            }
        } catch {
            purchaseError = "Failed to restore: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Internal Methods

    func loadProducts() async {
        isLoadingProducts = true
        productLoadError = nil

        do {
            let productIds = SubscriptionProduct.allCases.map { $0.rawValue }
            let storeProducts = try await Product.products(for: Set(productIds))
            products = Array(storeProducts)

            if products.isEmpty {
                productLoadError = "No subscription products available"
            }
        } catch {
            productLoadError = "Unable to load products: \(error.localizedDescription)"
        }

        isLoadingProducts = false
    }

    // MARK: - Private Methods

    private func updateSubscriptionStatus() async {
        var hasActiveSubscription = false
        var expirationDate: Date?
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable && transaction.revocationDate == nil {
                    hasActiveSubscription = true
                    expirationDate = transaction.expirationDate
                }
            }
        }

        isSubscribed = hasActiveSubscription
        subscriptionExpirationDate = expirationDate
    }

    private func updateTrialStatus() {
        if firstLaunchDate == nil {
            firstLaunchDate = Date()
        }

        guard let firstLaunch = firstLaunchDate else {
            isTrialActive = false
            trialDaysRemaining = 0
            return
        }

        let now = Date()
        let calendar = Calendar.current

        if let trialEnd = calendar.date(byAdding: .day, value: trialDurationDays, to: firstLaunch) {
            if now < trialEnd {
                isTrialActive = true
                let components = calendar.dateComponents([.day], from: now, to: trialEnd)
                trialDaysRemaining = max(0, (components.day ?? 0) + 1)
            } else {
                isTrialActive = false
                trialDaysRemaining = 0
            }
        }
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        if transaction.productType == .autoRenewable && transaction.revocationDate == nil {
                            self.isSubscribed = true
                            self.subscriptionExpirationDate = transaction.expirationDate
                        }
                    }
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Transaction verification failed"
        }
    }
}

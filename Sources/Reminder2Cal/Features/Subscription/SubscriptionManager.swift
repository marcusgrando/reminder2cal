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
                await updateSubscriptionStatus()
                await transaction.finish()

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
        } catch {
            purchaseError = "Failed to restore purchases: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Private Methods

    func loadProducts() async {
        isLoadingProducts = true
        productLoadError = nil

        do {
            let productIds = SubscriptionProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIds)

            if products.isEmpty {
                productLoadError = "No subscription products available"
            }
        } catch {
            productLoadError = "Unable to connect to App Store"
            print("StoreKit error loading products: \(error)")
        }

        isLoadingProducts = false
    }

    private func updateSubscriptionStatus() async {
        var hasActiveSubscription = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productType == .autoRenewable {
                    hasActiveSubscription = true
                    break
                }
            }
        }

        isSubscribed = hasActiveSubscription
    }

    private func updateTrialStatus() {
        // Set first launch date if not set
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
                    await self.updateSubscriptionStatus()
                    await transaction.finish()
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

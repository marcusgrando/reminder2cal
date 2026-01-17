import AppKit
import StoreKit
import SwiftUI

struct PaywallView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    var onSubscribed: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            featuresSection
            
            if subscriptionManager.isSubscribed {
                subscriptionStatusSection
            } else {
                subscriptionSection
            }
            
            footerSection
        }
        .padding(24)
        .frame(width: 380, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: subscriptionManager.isSubscribed) { _, isSubscribed in
            if isSubscribed {
                onSubscribed?()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            Text("Reminder2Cal")
                .font(.title2)
                .fontWeight(.bold)

            statusBadge
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        if subscriptionManager.isSubscribed {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                Text("Subscribed")
            }
            .font(.subheadline)
            .foregroundColor(.primary.opacity(0.7))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        } else if subscriptionManager.isTrialActive {
            Text("\(subscriptionManager.trialDaysRemaining) days left in trial")
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        } else {
            Text("Trial ended")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            featureRow(icon: "arrow.triangle.2.circlepath", text: "Automatic sync Reminders to Calendar")
            featureRow(icon: "bell.badge", text: "Real-time updates")
            featureRow(icon: "lock.shield", text: "100% private - works offline")
            featureRow(icon: "arrow.clockwise", text: "Continuous improvements")
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.callout)
            Spacer()
        }
    }
    
    // MARK: - Subscription Status (when subscribed)
    
    private var subscriptionStatusSection: some View {
        VStack(spacing: 12) {
            // Status card (mirrors productCard layout)
            VStack(spacing: 6) {
                Text("Annual Subscription")
                    .font(.headline)

                if let expDate = subscriptionManager.subscriptionExpirationDate {
                    Text("Renews \(expDate.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("Active")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            
            // Close button (mirrors subscribeButton layout)
            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Subscription (when not subscribed)

    private var subscriptionSection: some View {
        VStack(spacing: 12) {
            if subscriptionManager.isLoadingProducts {
                ProgressView("Loading...")
                    .frame(height: 80)
            } else if let product = subscriptionManager.products.first {
                productCard(product: product)
                subscribeButton(product: product)
            } else {
                errorView
            }

            if let error = subscriptionManager.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.primary.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }

    private func productCard(product: Product) -> some View {
        VStack(spacing: 6) {
            Text(product.displayName)
                .font(.headline)

            HStack(spacing: 4) {
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                Text("/ year")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let subscription = product.subscription,
               let introOffer = subscription.introductoryOffer {
                Text("\(introOffer.period.value)-\(introOffer.period.unit.localizedDescription) free trial included")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private func subscribeButton(product: Product) -> some View {
        Button {
            Task {
                try? await subscriptionManager.purchase(product)
            }
        } label: {
            ZStack {
                // Invisible text to maintain size
                VStack(spacing: 2) {
                    Text("Subscribe Now")
                        .font(.headline)
                    Text("Auto-renews. Cancel anytime.")
                        .font(.caption)
                }
                .opacity(0)
                
                // Actual content
                if subscriptionManager.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    VStack(spacing: 2) {
                        Text("Subscribe Now")
                            .font(.headline)
                        Text("Auto-renews. Cancel anytime.")
                            .font(.caption)
                            .opacity(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .disabled(subscriptionManager.isLoading)
    }
    
    private var errorView: some View {
        VStack(spacing: 8) {
            Text(subscriptionManager.productLoadError ?? "Unable to load subscription")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task {
                    await subscriptionManager.loadProducts()
                }
            }
            .focusEffectDisabled()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            } label: {
                ZStack {
                    Text("Restore Purchases").opacity(0)
                    if subscriptionManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text("Restore Purchases")
                    }
                }
            }
            .buttonStyle(.link)
            .font(.callout)
            .focusEffectDisabled()
            .disabled(subscriptionManager.isLoading)

            HStack(spacing: 12) {
                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("•").foregroundColor(.secondary)
                Link("Privacy", destination: URL(string: "https://marcusgrando.github.io/reminder2cal/PRIVACY")!)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PaywallView()
}

extension Product.SubscriptionPeriod.Unit {
    var localizedDescription: String {
        switch self {
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        @unknown default: return "period"
        }
    }
}

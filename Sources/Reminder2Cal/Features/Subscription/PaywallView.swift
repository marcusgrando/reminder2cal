import StoreKit
import SwiftUI

struct PaywallView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    var onSubscribed: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
            headerSection
            featuresSection
            subscriptionSection
            footerSection
        }
        .padding(32)
        .frame(width: 420, height: 520)
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: subscriptionManager.isSubscribed) { _, isSubscribed in
            if isSubscribed {
                onSubscribed?()
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            if let image = NSImage(named: "reminder2cal.svg") {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 80, height: 80)
            } else {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 80, height: 80)
            }

            Text("Reminder2Cal")
                .font(.title)
                .fontWeight(.bold)

            if subscriptionManager.isTrialActive {
                trialBadge
            } else {
                Text("Your trial has ended")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var trialBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
            Text("\(subscriptionManager.trialDaysRemaining) days left in trial")
        }
        .font(.subheadline)
        .foregroundColor(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "arrow.triangle.2.circlepath", text: "Automatic sync between Reminders and Calendar")
            featureRow(icon: "bell.badge", text: "Real-time updates when reminders change")
            featureRow(icon: "lock.shield", text: "100% private - works offline")
            featureRow(icon: "arrow.clockwise", text: "Continuous updates and improvements")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.primary)
                .frame(width: 24)
            Text(text)
                .font(.callout)
            Spacer()
        }
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        VStack(spacing: 16) {
            if subscriptionManager.isLoadingProducts {
                loadingView
            } else if let product = subscriptionManager.products.first {
                productCard(product: product)
                subscriptionButton(product: product)
            } else {
                errorStateView
            }

            if let error = subscriptionManager.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading subscription options...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(height: 100)
    }

    private var errorStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundColor(.orange)

            Text("Unable to load subscription")
                .font(.subheadline)
                .fontWeight(.medium)

            if let error = subscriptionManager.productLoadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Try Again") {
                Task {
                    await subscriptionManager.loadProducts()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func productCard(product: Product) -> some View {
        VStack(spacing: 8) {
            Text(product.displayName)
                .font(.headline)

            if !product.description.isEmpty {
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            HStack(spacing: 4) {
                Text(product.displayPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                Text("/ year")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let subscription = product.subscription,
               let introOffer = subscription.introductoryOffer {
                HStack(spacing: 4) {
                    Image(systemName: "gift")
                    Text("\(introOffer.period.value)-\(introOffer.period.unit.localizedDescription) free trial")
                }
                .font(.caption)
                .foregroundColor(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func subscriptionButton(product: Product) -> some View {
        Button {
            Task {
                try? await subscriptionManager.purchase(product)
            }
        } label: {
            VStack(spacing: 4) {
                Text("Subscribe Now")
                    .font(.headline)
                Text("Auto-renews annually. Cancel anytime.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(subscriptionManager.isLoading)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .buttonStyle(.link)
            .font(.callout)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy", destination: URL(string: "https://marcusgrando.github.io/reminder2cal/PRIVACY")!)
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

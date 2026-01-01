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
            if let product = subscriptionManager.products.first {
                subscriptionButton(product: product)
            } else if subscriptionManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Text("Unable to load subscription options")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            if let error = subscriptionManager.purchaseError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private func subscriptionButton(product: Product) -> some View {
        Button {
            Task {
                try? await subscriptionManager.purchase(product)
            }
        } label: {
            VStack(spacing: 4) {
                Text("Subscribe for \(product.displayPrice)/year")
                    .font(.headline)
                Text("Auto-renews annually")
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

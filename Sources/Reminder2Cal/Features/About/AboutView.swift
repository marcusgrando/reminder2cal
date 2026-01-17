import AppKit
import SwiftUI

struct AboutView: View {
    var onClose: (() -> Void)?
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 100, height: 100)

            VStack(spacing: 5) {
                Text("Reminder2Cal")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 2) {
                Text("Copyright © 2025-2026 Marcus Grando.")
                Text("All rights reserved.")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(30)
        .frame(width: 300)
    }
}

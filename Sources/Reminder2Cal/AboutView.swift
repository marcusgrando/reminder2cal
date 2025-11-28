import SwiftUI

struct AboutView: View {
    var onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            if let image = NSImage(named: "reminder2cal.svg") {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 128, height: 128)
            } else {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 128, height: 128)
            }

            VStack(spacing: 5) {
                Text("Reminder2Cal")
                    .font(.title)
                    .fontWeight(.bold)

                Text(
                    "Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
                )
                .font(.subheadline)
                .foregroundColor(.secondary)
            }

            Text("Copyright © 2025 Marcus Grando. All rights reserved.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(width: 350)
    }
}

import SwiftUI

// MARK: - Permission Banner View

/// Shows a prominent banner when Accessibility permission is missing.
struct PermissionBannerView: View {
    @ObservedObject var accessibility: AccessibilityManager

    var body: some View {
        if !accessibility.isGranted {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Accessibility Permission Required")
                        .font(.subheadline.weight(.semibold))
                    Text("AutoClicker needs Accessibility access to simulate clicks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Grant Access") {
                    // Shows the system prompt, which itself links to System Settings.
                    accessibility.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            }
            .padding(12)
            .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

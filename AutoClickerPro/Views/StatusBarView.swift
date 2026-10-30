import SwiftUI

// MARK: - Status Bar View

/// Displays the current engine state: click count and elapsed time.
struct StatusBarView: View {
    @ObservedObject var engine: ClickEngine

    private var elapsed: TimeInterval {
        guard let start = engine.startDate else { return 0 }
        return Date().timeIntervalSince(start)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.6), radius: 4)

                Text(statusLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Click count
            HStack(spacing: 4) {
                Image(systemName: "cursorarrow.click")
                    .foregroundStyle(.secondary)
                Text("\(engine.clickCount)")
                    .font(.system(.body, design: .monospaced).weight(.medium))
            }
        }
        .padding(.vertical, 6)
    }

    private var statusColor: Color {
        if engine.isPaused { return .yellow }
        if engine.isRunning { return .green }
        return .gray
    }

    private var statusLabel: String {
        if engine.isPaused { return "Paused" }
        if engine.isRunning { return "Running" }
        return "Idle"
    }
}

import SwiftUI

// MARK: - Cursor Mode View (Fixed Target Points)

/// Multi-point coordinate queue with individual wait delays. Always fixed coordinates.
struct CursorModeView: View {
    @Binding var targets: [TargetPoint]

    @State private var pickingTargetId: UUID? = nil
    @State private var liveMousePosition: CGPoint = .zero
    @State private var mouseTimer: Timer?
    @State private var localMonitor: Any?
    @State private var globalMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Target Coordinates", systemImage: "scope")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    addTarget()
                } label: {
                    Label("Add Point", systemImage: "plus")
                        .font(.caption.weight(.medium))
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }

            Text("Clicks cycle through all targets. Each wait is added to the click interval.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Target rows
            VStack(spacing: 6) {
                ForEach($targets) { $target in
                    targetRow(target: $target)
                }
            }

            // Live coordinate picker status
            if let pickingId = pickingTargetId, let index = targets.firstIndex(where: { $0.id == pickingId }) {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(String(format: "Target P%d: (%.0f, %.0f) — Click anywhere to lock (Enter works inside this window)", index + 1, liveMousePosition.x, liveMousePosition.y))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)

                    Spacer()

                    Button("Cancel") {
                        stopPicking()
                    }
                    .controlSize(.small)
                }
                .padding(8)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .onDisappear { stopPicking() }
    }

    // MARK: - Target Row

    private func targetRow(target: Binding<TargetPoint>) -> some View {
        let id = target.wrappedValue.id
        let index = targets.firstIndex(where: { $0.id == id }) ?? 0
        let isPickingThis = (pickingTargetId == id)

        return HStack(spacing: 6) {
            // Target badge
            Text("P\(index + 1)")
                .font(.caption.weight(.bold))
                .foregroundStyle(isPickingThis ? .blue : .primary)
                .frame(width: 22, alignment: .leading)

            // X coordinate
            HStack(spacing: 2) {
                Text("X:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("X", value: target.x, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
            }

            // Y coordinate
            HStack(spacing: 2) {
                Text("Y:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Y", value: target.y, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
            }

            // Individual Delay
            HStack(spacing: 2) {
                Text("+Wait:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("ms", value: target.delayMs, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                Text("ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Pick coordinate button
            Button {
                startPicking(for: id)
            } label: {
                Image(systemName: "location.viewfinder")
                    .foregroundStyle(isPickingThis ? .blue : .primary)
            }
            .buttonStyle(.plain)
            .help("Click to target this coordinate on screen")

            // Delete point button
            if targets.count > 1 {
                Button {
                    deleteTarget(id: id)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Remove this target")
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            isPickingThis ? Color.blue.opacity(0.08) : Color.primary.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    // MARK: - Actions

    private func addTarget() {
        let lastTarget = targets.last
        let lastDelay = lastTarget?.delayMs ?? 0
        let newX = (lastTarget?.x ?? 480) + 20
        let newY = (lastTarget?.y ?? 480) + 20
        let newTarget = TargetPoint(x: newX, y: newY, delayMs: lastDelay)
        targets.append(newTarget)
    }

    private func deleteTarget(id: UUID) {
        guard targets.count > 1, let index = targets.firstIndex(where: { $0.id == id }) else { return }
        if pickingTargetId == id {
            stopPicking()
        }
        targets.remove(at: index)
    }

    // MARK: - Coordinate Picking

    private func capturePosition(for targetId: UUID) {
        if let loc = CGEvent(source: nil)?.location,
           let index = targets.firstIndex(where: { $0.id == targetId }) {
            targets[index].x = round(Double(loc.x))
            targets[index].y = round(Double(loc.y))
        }
        stopPicking()
    }

    private func startPicking(for targetId: UUID) {
        stopPicking()
        pickingTargetId = targetId
        startMouseTracking()

        // Local monitor (when app window has focus): Esc to cancel, Enter/Space to lock
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Esc (53) cancels picking
            if event.keyCode == 53 {
                self.stopPicking()
                return nil
            }
            // Return (36) or Space (49) locks position
            if event.keyCode == 36 || event.keyCode == 49 {
                if let id = self.pickingTargetId {
                    self.capturePosition(for: id)
                }
                return nil
            }
            return event
        }

        // Global monitor: clicks in other apps. Mouse-only, because global key
        // monitoring would require the Input Monitoring permission.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { _ in
            DispatchQueue.main.async {
                if let id = self.pickingTargetId {
                    self.capturePosition(for: id)
                }
            }
        }
    }

    private func stopPicking() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        stopMouseTracking()
        pickingTargetId = nil
    }

    private func startMouseTracking() {
        stopMouseTracking()
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            liveMousePosition = CGEvent(source: nil)?.location ?? .zero
        }
    }

    private func stopMouseTracking() {
        mouseTimer?.invalidate()
        mouseTimer = nil
    }
}

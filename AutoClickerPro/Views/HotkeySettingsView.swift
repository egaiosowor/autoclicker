import AppKit
import Carbon
import SwiftUI

// MARK: - Hotkey Settings View

/// Displays and allows interactive customization of global hotkey bindings.
struct HotkeySettingsView: View {
    @ObservedObject var hotkeys: HotkeyManager
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Global Hotkeys", systemImage: "keyboard")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                // Status badge
                if hotkeys.isListening {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.orange)
                            .frame(width: 6, height: 6)
                        Text(hotkeys.tapFailed ? "Needs Accessibility permission" : "Inactive")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.orange)
                    }
                }
            }

            VStack(spacing: 8) {
                hotkeyRow(
                    label: "Start / Stop",
                    description: "Toggle auto clicking on/off",
                    combo: $hotkeys.startStopCombo,
                    action: .toggleStartStop,
                    defaultCombo: Constants.defaultStartStopCombo
                )

                Divider()

                hotkeyRow(
                    label: "Pause / Resume",
                    description: "Temporarily pause clicking",
                    combo: $hotkeys.pauseResumeCombo,
                    action: .togglePause,
                    defaultCombo: Constants.defaultPauseResumeCombo
                )
            }
            .padding(12)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

            if let errorMessage = errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            // Presets and helper text
            HStack {
                Text("Click a key to record. Press ⎋ Esc to cancel.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Button("Reset to Defaults (⌥⌘S / ⌥⌘P)") {
                        hotkeys.resetToDefaults()
                    }
                    Button("Use Function Keys (F6 / ⇧F6)") {
                        hotkeys.setToF6Defaults()
                    }
                } label: {
                    Text("Presets")
                        .font(.caption2)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    @ViewBuilder
    private func hotkeyRow(
        label: String,
        description: String,
        combo: Binding<KeyCombo>,
        action: HotkeyAction,
        defaultCombo: KeyCombo
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption.weight(.medium))
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HotkeyRecorderButton(
                combo: combo,
                validate: { hotkeys.validate($0, for: action) },
                onError: { errorMessage = $0 }
            )

            Button {
                if let error = hotkeys.validate(defaultCombo, for: action) {
                    errorMessage = error
                } else {
                    combo.wrappedValue = defaultCombo
                    errorMessage = nil
                }
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reset to default (\(defaultCombo.displayString))")
        }
    }
}

// MARK: - Hotkey Recorder Button

struct HotkeyRecorderButton: View {
    @Binding var combo: KeyCombo
    var validate: (KeyCombo) -> String? = { _ in nil }
    var onError: (String?) -> Void = { _ in }
    @State private var isRecording: Bool = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            HStack(spacing: 6) {
                if isRecording {
                    Text("Type keys...")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.white)
                } else {
                    Text(combo.displayString)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isRecording ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isRecording ? Color.accentColor : Color.secondary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        stopRecording()
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            // Escape cancels recording without changing combo
            if event.keyCode == UInt16(kVK_Escape) {
                self.stopRecording()
                return nil
            }

            let mods = event.modifierFlags.intersection([.command, .shift, .option, .control])
            let newCombo = KeyCombo(keyCode: event.keyCode, modifiers: mods)
            if let error = self.validate(newCombo) {
                self.onError(error)
            } else {
                self.onError(nil)
                self.combo = newCombo
            }
            self.stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let activeMonitor = monitor {
            NSEvent.removeMonitor(activeMonitor)
            monitor = nil
        }
    }
}

import AppKit
import Carbon
import SwiftUI

// MARK: - Hotkey Settings View

/// Displays and allows interactive customization of global hotkey bindings for the current profile.
struct HotkeySettingsView: View {
    @ObservedObject var hotkeys: HotkeyManager
    @Binding var combo: KeyCombo?
    let profileID: UUID
    let library: ProfileLibrary
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Profile Hotkey", systemImage: "keyboard")
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
                    label: "Start / Stop Shortcut",
                    description: "Triggers this sequence (or press ⎋ Esc to stop)",
                    combo: $combo
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
                Text("Click to record. Press ⎋ Esc to emergency stop.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Button("Default (⌥⌘S)") {
                        applyPreset(Constants.defaultStartStopCombo)
                    }
                    Button("Function Key (F6)") {
                        applyPreset(Constants.defaultF6StartStopCombo)
                    }
                    if combo != nil {
                        Divider()
                        Button("Remove Shortcut") {
                            combo = nil
                            errorMessage = nil
                        }
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

    private func applyPreset(_ preset: KeyCombo) {
        if let error = hotkeys.validate(preset) {
            errorMessage = error
            return
        }
        if let conflict = library.hotkeyConflict(preset, excluding: profileID) {
            errorMessage = "Already used by '\(conflict.name)'"
            return
        }
        combo = preset
        errorMessage = nil
    }

    @ViewBuilder
    private func hotkeyRow(
        label: String,
        description: String,
        combo: Binding<KeyCombo?>
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
                validate: { hotkeys.validate($0) },
                conflictCheck: { testCombo in
                    library.hotkeyConflict(testCombo, excluding: profileID)?.name
                },
                onError: { errorMessage = $0 }
            )

            if combo.wrappedValue != nil {
                Button {
                    combo.wrappedValue = nil
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove shortcut")
            }
        }
    }
}

// MARK: - Hotkey Recorder Button

struct HotkeyRecorderButton: View {
    @Binding var combo: KeyCombo?
    var validate: (KeyCombo) -> String? = { _ in nil }
    var conflictCheck: (KeyCombo) -> String? = { _ in nil }
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
                } else if let combo = combo {
                    Text(combo.displayString)
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(.primary)
                } else {
                    Text("None (Click to record)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            } else if let conflictName = self.conflictCheck(newCombo) {
                self.onError("Already used by '\(conflictName)'")
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

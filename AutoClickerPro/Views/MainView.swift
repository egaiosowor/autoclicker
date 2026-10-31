import SwiftUI

// MARK: - Main View

/// The primary app window assembling all configuration panels and profile management.
struct MainView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            // Scrollable content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Permission banner
                    PermissionBannerView(accessibility: appState.accessibility)

                    // Error banner
                    if let error = appState.engine.engineError {
                        errorBanner(error)
                    }

                    // Interval
                    IntervalPickerView(
                        intervalValue: appState.intervalValueBinding,
                        intervalUnit: appState.intervalUnitBinding
                    )

                    // Click type
                    ClickTypePickerView(
                        button: appState.clickButtonBinding,
                        action: appState.clickActionBinding
                    )

                    // Execution limit
                    ExecutionLimitView(
                        isFinite: appState.executionLimitIsFiniteBinding,
                        count: appState.executionLimitCountBinding,
                        targetCount: appState.selectedProfile.targets.count
                    )

                    // Cursor mode (Fixed targets)
                    CursorModeView(
                        targets: appState.targetsBinding,
                        engine: appState.engine
                    )

                    // Safety toggle
                    Toggle(isOn: appState.cursorInterruptEnabledBinding) {
                        Label("Stop if mouse moves", systemImage: "hand.raised.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .toggleStyle(.switch)

                    // Hotkey settings for currently selected profile
                    HotkeySettingsView(
                        hotkeys: appState.hotkeys,
                        combo: appState.selectedHotkeyBinding,
                        profileID: appState.library.selectedID,
                        library: appState.library
                    )
                }
                .padding(20)
            }

            Divider()

            // Footer with action buttons
            footer
                .padding(16)
        }
        .frame(
            minWidth: Constants.windowWidth,
            maxWidth: Constants.windowWidth,
            minHeight: Constants.windowHeight,
            maxHeight: Constants.windowHeight
        )
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AutoClicker Pro")
                    .font(.title2.weight(.bold))

                Spacer()

                StatusBarView(
                    engine: appState.engine,
                    activeProfileName: appState.runningProfile?.name
                )
            }

            ProfilePickerView(appState: appState)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        FooterActionView(engine: appState.engine) {
            appState.toggleEngine()
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private func errorBanner(_ error: EngineError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error.localizedDescription)
                .font(.caption)
            Spacer()
            Button {
                appState.engine.engineError = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Footer Action View

/// Observes engine directly so the Start / Stop button immediately updates when finite sequences end.
struct FooterActionView: View {
    @ObservedObject var engine: ClickEngine
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: engine.isRunning ? "stop.fill" : "play.fill")
                Text(engine.isRunning ? "Stop" : "Start")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
        }
        .buttonStyle(.borderedProminent)
        .tint(engine.isRunning ? .red : .accentColor)
        .controlSize(.large)
    }
}

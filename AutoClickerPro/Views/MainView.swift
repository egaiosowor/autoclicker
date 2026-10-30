import SwiftUI

// MARK: - Main View

/// The primary app window assembling all configuration panels.
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
                        intervalValue: $appState.intervalValue,
                        intervalUnit: $appState.intervalUnit
                    )

                    // Click type
                    ClickTypePickerView(
                        button: $appState.clickButton,
                        action: $appState.clickAction
                    )

                    // Execution limit
                    ExecutionLimitView(
                        isFinite: $appState.executionLimitIsFinite,
                        count: $appState.executionLimitCount
                    )

                    // Cursor mode (Fixed targets)
                    CursorModeView(targets: $appState.targets)

                    // Safety toggle
                    Toggle(isOn: $appState.cursorInterruptEnabled) {
                        Label("Stop if mouse moves", systemImage: "hand.raised.fill")
                            .font(.subheadline.weight(.medium))
                    }
                    .toggleStyle(.switch)

                    // Hotkey info
                    HotkeySettingsView(hotkeys: appState.hotkeys)
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("AutoClicker Pro")
                    .font(.title2.weight(.bold))

                StatusBarView(engine: appState.engine)
            }
            Spacer()
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            // Start / Stop button
            Button {
                appState.toggleEngine()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: appState.engine.isRunning ? "stop.fill" : "play.fill")
                    Text(appState.engine.isRunning ? "Stop" : "Start")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(appState.engine.isRunning ? .red : .accentColor)
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: [])

            // Pause / Resume button (only when running)
            if appState.engine.isRunning {
                Button {
                    appState.togglePause()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: appState.engine.isPaused ? "play.fill" : "pause.fill")
                        Text(appState.engine.isPaused ? "Resume" : "Pause")
                    }
                    .frame(height: 36)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appState.engine.isRunning)
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

import AppKit
import SwiftUI

// MARK: - Window Accessor

struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Main App

@main
struct AutoClickerProApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainView(appState: appState)
                .background(WindowAccessor { window in
                    let size = NSSize(width: Constants.windowWidth, height: Constants.windowHeight)
                    window.setContentSize(size)
                    window.minSize = size
                    window.maxSize = size
                    window.styleMask.remove(.resizable)
                    window.isMovableByWindowBackground = true
                })
        }
        .windowStyle(.hiddenTitleBar)
    }
}

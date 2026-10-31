import SwiftUI

// MARK: - Profile Picker View

/// Segmented toolbar component for toggling between the two profiles.
struct ProfilePickerView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            Picker("Profile", selection: Binding(
                get: { appState.library.selectedID },
                set: { appState.selectProfile(id: $0) }
            )) {
                ForEach(appState.library.profiles) { profile in
                    Text("\(profile.name) (\(profile.hotkey?.displayString ?? "None"))")
                        .tag(profile.id)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.vertical, 2)
    }
}

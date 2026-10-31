import SwiftUI

// MARK: - Profile Picker View

/// Header toolbar component allowing fast profile switching and management.
struct ProfilePickerView: View {
    @ObservedObject var appState: AppState
    @State private var isRenaming = false
    @State private var renameText = ""

    var body: some View {
        HStack(spacing: 8) {
            Label("Profile", systemImage: "square.stack.3d.up.fill")
                .font(.subheadline.weight(.semibold))

            // Profile dropdown picker
            Picker("", selection: Binding(
                get: { appState.library.selectedID },
                set: { appState.selectProfile(id: $0) }
            )) {
                ForEach(appState.library.profiles) { profile in
                    HStack {
                        Text(profile.name)
                        if let hotkey = profile.hotkey {
                            Text("(\(hotkey.displayString))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(profile.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            // Add new profile button
            Button {
                appState.addProfile()
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .help("Add new profile")

            // Profile actions menu (Rename, Duplicate, Delete, Import, Export)
            Menu {
                Button {
                    renameText = appState.selectedProfile.name
                    isRenaming = true
                } label: {
                    Label("Rename...", systemImage: "pencil")
                }

                Button {
                    appState.duplicateProfile(id: appState.library.selectedID)
                } label: {
                    Label("Duplicate", systemImage: "plus.square.on.square")
                }

                Button(role: .destructive) {
                    appState.deleteProfile(id: appState.library.selectedID)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(appState.library.profiles.count <= 1)

                Divider()

                Button {
                    appState.exportProfiles()
                } label: {
                    Label("Export Profiles...", systemImage: "square.and.arrow.up")
                }

                Button {
                    appState.importProfiles()
                } label: {
                    Label("Import Profiles...", systemImage: "square.and.arrow.down")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption.weight(.semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Profile actions")
        }
        .padding(.vertical, 4)
        .alert("Rename Profile", isPresented: $isRenaming) {
            TextField("Profile Name", text: $renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                appState.renameProfile(id: appState.library.selectedID, newName: renameText)
            }
        } message: {
            Text("Enter a new name for this profile.")
        }
    }
}

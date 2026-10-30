import SwiftUI

// MARK: - Click Type Picker View

/// Segmented pickers for mouse button (L/R/M) and click action (1×/2×/3×).
struct ClickTypePickerView: View {
    @Binding var button: ClickButton
    @Binding var action: ClickAction

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Click Type", systemImage: "cursorarrow.click.2")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Button")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Button", selection: $button) {
                        ForEach(ClickButton.allCases) { btn in
                            Text(btn.rawValue).tag(btn)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Action")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Action", selection: $action) {
                        ForEach(ClickAction.allCases) { act in
                            Text(act.shortLabel).tag(act)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
        }
    }
}

import SwiftUI

// MARK: - Execution Limit View

/// Toggle between infinite and finite click limits.
struct ExecutionLimitView: View {
    @Binding var isFinite: Bool
    @Binding var count: Int
    var targetCount: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Repeat", systemImage: "repeat")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 12) {
                Picker("Mode", selection: $isFinite) {
                    Text("Until Stopped").tag(false)
                    Text("Fixed Count").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if isFinite {
                    HStack(spacing: 4) {
                        TextField("Count", value: $count, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                            .onSubmit { NSApp.keyWindow?.makeFirstResponder(nil) }

                        Stepper("", value: $count, in: 1...Int.max)
                            .labelsHidden()

                        Text(targetCount > 1 ? (count == 1 ? "cycle" : "cycles") : (count == 1 ? "time" : "times"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

import SwiftUI

// MARK: - Execution Limit View

/// Toggle between infinite and finite click limits.
struct ExecutionLimitView: View {
    @Binding var isFinite: Bool
    @Binding var count: Int

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
                    TextField("Count", value: $count, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)

                    Stepper("", value: $count, in: 1...Int.max)
                        .labelsHidden()
                }
            }
        }
    }
}

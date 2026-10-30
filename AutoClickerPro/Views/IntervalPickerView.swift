import SwiftUI

// MARK: - Interval Picker View

/// Controls for setting the click interval value and unit.
struct IntervalPickerView: View {
    @Binding var intervalValue: Double
    @Binding var intervalUnit: IntervalUnit

    /// Warning text from SafetyGuard, if applicable.
    private var warning: String? {
        SafetyGuard.intervalWarning(intervalUnit.toSeconds(intervalValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Click Interval", systemImage: "timer")
                .font(.subheadline.weight(.semibold))

            HStack(spacing: 8) {
                TextField("Interval", value: $intervalValue, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .onChange(of: intervalValue) { newValue in
                        if newValue < 1 {
                            intervalValue = 1
                        }
                    }
                    #if os(macOS)
                    .onSubmit {} // dismiss keyboard
                    #endif

                Picker("Unit", selection: $intervalUnit) {
                    ForEach(IntervalUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            if let warning = warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

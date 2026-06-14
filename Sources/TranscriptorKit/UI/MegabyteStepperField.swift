import SwiftUI

/// A compact numeric editor styled like the native macOS stepper field (e.g. the
/// "Font size … pt" control): the right-aligned number and the up/down chevrons
/// share a single recessed rounded box, with the unit label ("MB") sitting just
/// outside the box.
///
/// Both typed entry and the chevrons are clamped to `range`, so the value can
/// never leave the supported bounds.
struct MegabyteStepperField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 64

    private var clampedBinding: Binding<Int> {
        Binding(
            get: { clamp(value) },
            set: { value = clamp($0) }
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField("", value: clampedBinding, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .frame(width: 44)

                steppers
            }
            .padding(.leading, 9)
            .padding(.trailing, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(.separator, lineWidth: 0.5)
            )

            Text("MB")
                .foregroundStyle(.secondary)
        }
    }

    /// The stacked up/down chevrons, drawn as plain glyphs (no nested border) so
    /// they read as part of the same box, matching the native stepper field.
    private var steppers: some View {
        VStack(spacing: 1) {
            chevron("chevron.up", enabled: value < range.upperBound) { value = clamp(value + step) }
            chevron("chevron.down", enabled: value > range.lowerBound) { value = clamp(value - step) }
        }
    }

    private func chevron(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 7, weight: .black))
                .frame(width: 13, height: 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
        .disabled(!enabled)
    }

    private func clamp(_ newValue: Int) -> Int {
        min(max(newValue, range.lowerBound), range.upperBound)
    }
}

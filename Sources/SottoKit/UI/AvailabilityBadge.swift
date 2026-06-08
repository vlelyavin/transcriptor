import SwiftUI

public struct AvailabilityBadge: View {
    private let availability: FeatureAvailability

    public init(availability: FeatureAvailability) {
        self.availability = availability
    }

    public var body: some View {
        Text(availability.badgeLabel)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(backgroundColor.opacity(0.16), in: Capsule())
            .foregroundStyle(backgroundColor)
    }

    private var backgroundColor: Color {
        switch availability {
        case .planned:
            .orange
        case .unavailable:
            .secondary
        }
    }
}

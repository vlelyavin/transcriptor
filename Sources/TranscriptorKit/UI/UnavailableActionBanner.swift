import SwiftUI

public struct UnavailableActionBanner: View {
    private let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        Label(message, systemImage: "info.circle")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

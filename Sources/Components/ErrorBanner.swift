import SwiftUI

/// A shared error banner displayed at the top of a module view.
/// Shows a red triangle icon, error message, and dismiss button.
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Brand.accentRed)
            Text(message)
                .monoFont(11)
                .foregroundColor(Brand.accentRed)
            Spacer()
            Button(L10n.errorDismiss, action: onDismiss)
                .monoFont(10)
                .foregroundColor(Brand.textDim)
        }
        .padding(Brand.marginTight)
        .background(Brand.bgCard.opacity(0.95))
        .overlay(
            Rectangle()
                .fill(Brand.accentRed)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

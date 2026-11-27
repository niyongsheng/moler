import SwiftUI

/// Inline advisory row used by the Clean and Purge review screens.
struct NoticeRow: View {
    let icon: String
    let text: String
    let color: Color
    var lineLimit: Int? = nil

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).monoFont(9).lineLimit(lineLimit)
            Spacer()
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

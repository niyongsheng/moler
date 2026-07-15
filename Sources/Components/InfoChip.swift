import SwiftUI

/// A small label-value chip with monospace font, thin padding, and frosted background.
/// Used in instrument panels for compact metric readouts (e.g. CPU load, battery stats).
struct InfoChip: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 2) {
            Text(label).monoFont(8).foregroundColor(Brand.textDim)
            Text(value).monoFont(9).foregroundColor(Brand.accentGold)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Material.ultraThin).cornerRadius(3)
    }
}

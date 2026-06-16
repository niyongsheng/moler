import SwiftUI

/// Result summary after a successful clean operation.
struct CleanResultView: View {
    let freedBytes: Int64
    let filesRemoved: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success reticle
            ZStack {
                Reticle(strokeColor: Brand.accentGold, lineWidth: 1, armLength: 16)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Brand.accentGold)
            }

            // Title
            VStack(spacing: 4) {
                Text(L10n.cleanDoneTitle)
                    .titleFont(28)
                    .kerning(8)
                    .foregroundColor(Brand.accentGold)

                Text(L10n.cleanDoneSubtitle)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }

            // Stats
            GlassCard {
                HStack(spacing: 32) {
                    statBlock(
                        label: L10n.cleanDoneSpaceFreed,
                        value: formatBytes(freedBytes),
                        accent: Brand.accentGold
                    )
                    Divider()
                        .frame(height: 40)
                        .background(Brand.lineColor)
                    statBlock(
                        label: L10n.cleanDoneFilesRemoved,
                        value: Format.count(filesRemoved),
                        accent: Brand.accentOrange
                    )
                }
            }
            .frame(maxWidth: 380)

            // Return button
            Button(action: onDone) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L10n.cleanDoneNewScan)
                        .titleFont(12)
                        .kerning(4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Brand.accentOrange, lineWidth: 1)
                )
                .foregroundColor(Brand.accentOrange)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func statBlock(label: String, value: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .monoFont(9)
                .kerning(2)
                .foregroundColor(Brand.textDim)
            Text(value)
                .titleFont(24)
                .kerning(2)
                .foregroundColor(accent)
        }
    }
}

#Preview {
    CleanResultView(
        freedBytes: 3_500_000_000,
        filesRemoved: 847,
        onDone: {}
    )
    .frame(width: 700, height: 500)
    .padding()
    .background(Brand.bgNavy)
    .environment(\.colorScheme, .dark)
}

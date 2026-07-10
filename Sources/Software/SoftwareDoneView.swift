import SwiftUI

/// Completion summary after an app uninstall.
struct SoftwareDoneView: View {
    let result: UninstallResult
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Reticle(strokeColor: Brand.accentGold.opacity(0.5), lineWidth: 0.5, armLength: 20)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Brand.accentGold)
            }

            VStack(spacing: 6) {
                Text(L10n.softwareDoneTitle)
                    .titleFont(28)
                    .kerning(8)
                    .foregroundColor(Brand.accentGold)

                Text(L10n.softwareDoneSubtitle)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }

            GlassCard {
                VStack(spacing: Brand.unit * 2) {
                    DataRow(label: L10n.softwareDoneAppsRemoved, value: "\(result.appNames.count)")
                    DataRow(label: L10n.softwareDoneBytesFreed, value: formatBytes(result.bytesFreed))
                    DataRow(label: L10n.softwareDoneDuration, value: formattedDuration(result.durationSeconds))
                }
            }
            .frame(maxWidth: 360)

            Spacer()

            Button(action: onReset) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L10n.softwareDoneBack)
                        .titleFont(14)
                        .kerning(6)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Brand.accentOrange.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.accentOrange, lineWidth: 1))
                .foregroundColor(Brand.accentOrange)
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}

import SwiftUI
import AppKit

/// Guided install view shown when the `mo` CLI is missing.
/// Moler can't run without it, but instead of a dead-end alert we show the
/// exact install command (copyable) and a Recheck button — we never run
/// an installer on the user's behalf. Once `mo` is found, `onReady` fires
/// and the app opens its main window.
struct MoleInstallView: View {
    let onReady: () -> Void

    @State private var checking = false
    @State private var stillMissing = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title
            VStack(alignment: .leading, spacing: 6) {
                Label(L10n.installTitle, systemImage: "shippingbox")
                    .titleFont(20)
                    .foregroundColor(Brand.accentOrange)

                Text(L10n.installMessage)
                    .bodyFont(13)
                    .foregroundColor(Brand.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Install command box
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.installSubtitle)
                    .monoFont(9)
                    .kerning(0.6)
                    .foregroundColor(Brand.textDim)

                HStack {
                    Text(MoleCLI.installCommand)
                        .monoFont(12)
                        .foregroundColor(Brand.textPrimary)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(MoleCLI.installCommand, forType: .string)
                        copied = true
                    } label: {
                        Label(copied ? L10n.installCopied : L10n.installCopy,
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .monoFont(10)
                            .foregroundColor(Brand.accentGold)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Brand.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Brand.lineColor, lineWidth: 1))

                Button { NSWorkspace.shared.open(MoleCLI.repoURL) } label: {
                    Text(L10n.installOtherOptions)
                        .monoFont(10)
                        .foregroundColor(Brand.textDim)
                }
                .buttonStyle(.plain)
            }

            if stillMissing {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Brand.accentGold)
                    Text(L10n.installStillMissing)
                        .monoFont(10)
                        .foregroundColor(Brand.accentGold)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Brand.accentGold.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Spacer(minLength: 0)

            // Footer buttons
            HStack(spacing: 12) {
                Spacer()
                Button(L10n.installQuit) { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .monoFont(12)
                    .foregroundColor(Brand.textDim)
                Button(action: recheck) {
                    Text(checking ? L10n.installChecking : L10n.installRecheck)
                        .titleFont(12)
                        .kerning(3)
                        .foregroundColor(Brand.accentOrange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Brand.accentOrange.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Brand.accentOrange, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(checking)
            }
        }
        .padding(24)
        .frame(width: 460, height: 340)
        .background(Brand.bgNavy)
        .environment(\.colorScheme, .dark)
    }

    private func recheck() {
        checking = true; stillMissing = false; copied = false
        DispatchQueue.global(qos: .userInitiated).async {
            let found = MoleCLI.findExecutable() != nil
            DispatchQueue.main.async {
                checking = false
                if found { onReady() } else { stillMissing = true }
            }
        }
    }
}

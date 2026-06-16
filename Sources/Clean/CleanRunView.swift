import SwiftUI

/// Live terminal-style log output during the clean operation.
struct CleanRunView: View {
    let log: [String]
    let progress: Double

    var body: some View {
        VStack(spacing: 0) {
            // Header
            InstrumentPanel(
                title: L10n.cleanRunTitle,
                subtitle: L10n.cleanRunSubtitle,
                badge: "\(Int(progress * 100))%"
            ) {
                DataRow(label: L10n.cleanRunStatus, value: L10n.cleanRunExecuting)
            }
            .padding(.bottom, Brand.margin)

            // Terminal log output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if log.isEmpty {
                            // Show simulated progress while waiting
                            HStack(spacing: 4) {
                                PulseGlow()
                                TypewriterLabel(L10n.cleanRunInit)
                            }
                            .padding(.vertical, 4)
                        } else {
                            ForEach(Array(log.enumerated()), id: \.offset) { i, line in
                                terminalLine(line)
                                    .id(i)
                            }
                        }
                    }
                    .padding(Brand.marginTight)
                }
                .onChange(of: log.count) { _, newCount in
                    if newCount > 0 {
                        withAnimation {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Brand.bgCard.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Brand.lineColor, lineWidth: 0.5)
            )

            // Progress bar
            ProgressGlow(progress: progress)
                .frame(maxWidth: .infinity)
                .padding(.top, Brand.margin)
        }
    }

    // MARK: - Terminal Line

    private func terminalLine(_ text: String) -> some View {
        HStack(spacing: 4) {
            Text(">")
                .monoFont(10)
                .foregroundColor(Brand.accentOrange)
            Text(text.trimmingCharacters(in: .whitespaces))
                .monoFont(11)
                .foregroundColor(
                    text.contains("error") || text.contains("fail")
                        ? Brand.accentRed
                        : Brand.textPrimary
                )
                .lineLimit(2)
        }
    }
}

#Preview {
    CleanRunView(
        log: [
            "Scanning /Users/nico/Library/Caches...",
            "Removed: com.apple.bird/... (124MB)",
            "Removed: Xcode/DerivedData/... (890MB)",
            "Removed: npm/_cacache/... (340MB)",
            "Cleaning temp files...",
        ],
        progress: 0.65
    )
    .frame(width: 700, height: 400)
    .padding()
    .background(Brand.bgNavy)
    .environment(\.colorScheme, .dark)
}

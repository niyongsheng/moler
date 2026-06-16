import SwiftUI

/// NASA-Punk terminal-style typewriter text animation.
/// Characters appear one-by-one with an optional blinking cursor.
struct TypewriterLabel: View {
    let fullText: String
    let speed: TimeInterval  // seconds per character

    @State private var displayedCount: Int = 0
    @State private var cursorVisible: Bool = true

    init(_ fullText: String, speed: TimeInterval = 0.03) {
        self.fullText = fullText
        self.speed = speed
    }

    var body: some View {
        HStack(spacing: 0) {
            Text(String(fullText.prefix(displayedCount)))
                .monoFont(12)
                .foregroundColor(Brand.textPrimary)

            // Blinking cursor (always present in hierarchy to prevent height fluctuation)
            Rectangle()
                .fill(Brand.accentOrange)
                .frame(width: 7, height: 14)
                .opacity(cursorVisible ? 1 : 0)
        }
        .onAppear { startTyping() }
        .onDisappear { displayedCount = 0 }
    }

    private func startTyping() {
        displayedCount = 0
        // Blinking cursor timer
        Timer.scheduledTimer(withTimeInterval: 0.53, repeats: true) { _ in
            cursorVisible.toggle()
        }

        // Type each character
        if fullText.isEmpty { return }
        Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { timer in
            if displayedCount < fullText.count {
                displayedCount += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

#Preview {
    TypewriterLabel("> INITIATING_DEEP_SCAN_SEQUENCE...")
        .padding()
        .background(Brand.bgNavy)
        .environment(\.colorScheme, .dark)
}

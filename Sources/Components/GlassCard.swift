import SwiftUI
import AppKit

/// A frosted-glass card backed by NSVisualEffectView.
/// Mirrors NASA-Punk's "glass cockpit" aesthetic.
struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = Brand.margin

    init(padding: CGFloat = Brand.margin, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Brand.lineColor, lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Visual Effect Bridge

/// NSVisualEffectView wrapped for SwiftUI.
struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

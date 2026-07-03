import SwiftUI

/// A reusable rounded card surface used across the dashboard.
///
/// Delegates to the design system's one true card treatment (`.dsCard`):
/// gradient-tinted `inkElev` surface, top-lit hairline border, continuous
/// corners, and a soft grounding shadow. Content is padded on the 8pt grid.
/// Nothing here hard-codes a foreground color, so callers control their own
/// text/glyph styling.
struct CardContainer<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = DS.Space.lg,
         @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCard(padding: padding)
    }
}

#Preview {
    ZStack {
        DS.AmbientBackground()
        VStack(spacing: DS.Space.md) {
            CardContainer {
                Text("Card content")
                    .foregroundStyle(Color.textHi)
            }
            CardContainer(padding: DS.Space.sm) {
                Text("Tighter card")
                    .foregroundStyle(Color.textMid)
            }
        }
        .padding()
    }
}

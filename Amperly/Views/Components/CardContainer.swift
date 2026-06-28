import SwiftUI

/// A reusable rounded card surface used across the dashboard.
///
/// Paints an `inkElev` background with a hairline stroke that reads as a subtle
/// raised tile on both the dark "electric" and light themes. Content is padded
/// and clipped to a continuous rounded rectangle. Nothing here hard-codes a
/// foreground color, so callers control their own text/glyph styling.
struct CardContainer<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat
    private let padding: CGFloat

    init(cornerRadius: CGFloat = 22,
         padding: CGFloat = 18,
         @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.inkElev)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.track.opacity(0.6), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

#Preview {
    ZStack {
        Color.inkBase.ignoresSafeArea()
        VStack(spacing: 16) {
            CardContainer {
                Text("Card content")
                    .foregroundStyle(Color.textHi)
            }
            CardContainer(cornerRadius: 16, padding: 12) {
                Text("Tighter card")
                    .foregroundStyle(Color.textMid)
            }
        }
        .padding()
    }
}

import SwiftUI

/// Renders a word's picture at the given size.
struct WordVisualView: View {
    let visual: Visual
    var size: CGFloat = 96
    var tint: Color = .accentColor

    var body: some View {
        Group {
            switch visual {
            case .emoji(let emoji):
                Text(emoji)
                    .font(.system(size: size * 0.8))
                    .minimumScaleFactor(0.5)
            case .symbol(let name):
                Image(systemName: name)
                    .resizable()
                    .scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                    .padding(size * 0.1)
            case .drawing(let name):
                Drawings.view(named: name)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension Word {
    var tint: Color { WordCategory.info(for: category).color }
}

#Preview {
    HStack {
        WordVisualView(visual: .emoji("🍎"))
        WordVisualView(visual: .symbol("figure.run"), tint: .green)
        WordVisualView(visual: .drawing("window"))
    }
}

import SwiftUI

/// Hand-made drawings for words that have no good emoji or SF Symbol.
enum Drawings {
    static let names = ["window", "stairs", "street"]

    @ViewBuilder
    static func view(named name: String) -> some View {
        switch name {
        case "window": WindowDrawing()
        case "stairs": StairsDrawing()
        case "street": StreetDrawing()
        default: Image(systemName: "questionmark.square.dashed").resizable().scaledToFit()
        }
    }
}

private struct WindowDrawing: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: s * 0.06)
                    .fill(LinearGradient(colors: [.cyan.opacity(0.35), .blue.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                // Curtains
                HStack {
                    CurtainShape().fill(.red.opacity(0.8)).frame(width: s * 0.22)
                    Spacer()
                    CurtainShape().fill(.red.opacity(0.8)).frame(width: s * 0.22).scaleEffect(x: -1)
                }
                // Frame and cross bars
                RoundedRectangle(cornerRadius: s * 0.06).stroke(.brown, lineWidth: s * 0.06)
                Rectangle().fill(.brown).frame(width: s * 0.05)
                Rectangle().fill(.brown).frame(height: s * 0.05)
            }
            .frame(width: s * 0.8, height: s * 0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

nonisolated private struct CurtainShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY),
                          control: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct StairsDrawing: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack(alignment: .bottomLeading) {
                StairsShape(steps: 5).fill(.orange.opacity(0.85))
                StairsShape(steps: 5).stroke(.brown, style: StrokeStyle(lineWidth: s * 0.03, lineJoin: .round))
            }
            .frame(width: s * 0.8, height: s * 0.8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

nonisolated private struct StairsShape: Shape {
    var steps: Int

    func path(in rect: CGRect) -> Path {
        let stepWidth = rect.width / CGFloat(steps)
        let stepHeight = rect.height / CGFloat(steps)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for i in 0..<steps {
            let x = rect.minX + CGFloat(i) * stepWidth
            let y = rect.maxY - CGFloat(i + 1) * stepHeight
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + stepWidth, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct StreetDrawing: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            ZStack {
                // Pavement and road in perspective
                RoadShape(topWidth: 0.5).fill(.gray.opacity(0.35))
                RoadShape(topWidth: 0.25).fill(.gray.opacity(0.85))
                // Centre dashes
                VStack(spacing: s * 0.05) {
                    ForEach(0..<4) { i in
                        Capsule().fill(.yellow)
                            .frame(width: s * (0.02 + 0.01 * CGFloat(i)), height: s * (0.06 + 0.02 * CGFloat(i)))
                    }
                }
                .offset(y: s * 0.08)
            }
            .frame(width: s * 0.85, height: s * 0.85)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

nonisolated private struct RoadShape: Shape {
    /// Width of the far end of the road as a fraction of the rect width.
    var topWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = rect.width * (1 - topWidth) / 2
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack {
        ForEach(Drawings.names, id: \.self) { Drawings.view(named: $0).frame(width: 100, height: 100) }
    }
}

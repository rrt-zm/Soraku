import SwiftUI

struct LevelCanvas: View {
    @Bindable var engine: LevelEngine
    var palette: Palette
    var reducedMotion: Bool

    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let inset = min(size.width, size.height) * 0.09
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { ctx, canvasSize in
                    draw(&ctx, size: canvasSize, inset: inset, time: t)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let p = normalize(value.location, size: size, inset: inset)
                        if !dragging {
                            dragging = true
                            engine.begin(at: p)
                        } else {
                            engine.move(to: p)
                        }
                    }
                    .onEnded { _ in
                        dragging = false
                        engine.end()
                    }
            )
        }
    }

    private func normalize(_ point: CGPoint, size: CGSize, inset: CGFloat) -> CGPoint {
        let w = max(1, size.width - inset * 2)
        let h = max(1, size.height - inset * 2)
        return CGPoint(x: (point.x - inset) / w, y: (point.y - inset) / h)
    }

    private func draw(_ ctx: inout GraphicsContext, size: CGSize, inset: CGFloat, time: Double) {
        let baseWidth = min(size.width, size.height) * 0.032
        let pulse = reducedMotion ? 0.5 : (0.5 + 0.5 * sin(time * 3))

        for seg in engine.level.segments {
            guard let a = engine.graph.nodePositions[seg.a], let b = engine.graph.nodePositions[seg.b] else { continue }
            let pa = InkRenderer.map(a, in: size, inset: inset)
            let pb = InkRenderer.map(b, in: size, inset: inset)
            var path = Path()
            path.move(to: pa); path.addLine(to: pb)
            let revealed = engine.isTiltRevealed(seg)
            if engine.inkedSegments.contains(seg.id) { continue }
            if !revealed {
                ctx.stroke(path, with: .color(palette.ink.opacity(0.05)),
                           style: StrokeStyle(lineWidth: baseWidth * 0.5, lineCap: .round, dash: [3, 7]))
            } else {
                let ghostColor = seg.color == .black ? palette.ghost : palette.ink(for: seg.color).opacity(0.2)
                ctx.stroke(path, with: .color(ghostColor),
                           style: StrokeStyle(lineWidth: baseWidth * 0.7, lineCap: .round))
            }
        }

        if let hint = engine.hintSegment, let seg = engine.graph.segment(hint),
           let a = engine.graph.nodePositions[seg.a], let b = engine.graph.nodePositions[seg.b] {
            let pa = InkRenderer.map(a, in: size, inset: inset)
            let pb = InkRenderer.map(b, in: size, inset: inset)
            var path = Path()
            path.move(to: pa); path.addLine(to: pb)
            ctx.stroke(path, with: .color(palette.accent.opacity(0.3 + 0.4 * pulse)),
                       style: StrokeStyle(lineWidth: baseWidth * (0.9 + 0.5 * pulse), lineCap: .round))
        }

        for cross in engine.level.crossings {
            let c = InkRenderer.map(cross.point, in: size, inset: inset)
            let r = baseWidth * 0.9
            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
            ctx.stroke(Path(ellipseIn: rect), with: .color(palette.accent.opacity(0.28)), style: StrokeStyle(lineWidth: 1.4))
        }

        let wet = engine.level.mechanic == .wetonwet
        for stroke in engine.committedStrokes {
            let points = stroke.nodeSequence.compactMap { engine.graph.nodePositions[$0] }.map { InkRenderer.map($0, in: size, inset: inset) }
            InkRenderer.drawStroke(&ctx, nodePoints: points, color: palette.ink(for: stroke.color),
                                   richness: wet ? min(1, stroke.richness + 0.2) : stroke.richness,
                                   baseWidth: baseWidth, taperEnd: true, bleed: true)
        }

        if let live = engine.liveStroke {
            var points = live.nodeSequence.compactMap { engine.graph.nodePositions[$0] }.map { InkRenderer.map($0, in: size, inset: inset) }
            if let finger = engine.fingerPoint {
                points.append(InkRenderer.map(finger, in: size, inset: inset))
            }
            InkRenderer.drawStroke(&ctx, nodePoints: points, color: palette.ink(for: live.color),
                                   richness: 0.85, baseWidth: baseWidth, taperEnd: true, bleed: true)
        }

        for blot in engine.blots {
            let c = InkRenderer.map(blot.position, in: size, inset: inset)
            let path = InkRenderer.blotPath(center: c, radius: CGFloat(blot.size) * size.width, seed: blot.seed)
            var blurCtx = ctx
            blurCtx.addFilter(.blur(radius: 2))
            blurCtx.fill(path, with: .color(palette.ink.opacity(0.5)))
        }

        for (node, pos) in engine.graph.nodePositions {
            let p = InkRenderer.map(pos, in: size, inset: inset)
            let hasOpen = engine.graph.adjacency[node]?.contains { !engine.inkedSegments.contains($0.segment) } ?? false
            let isCurrent = engine.currentNode == node
            if isCurrent {
                let r = baseWidth * (0.8 + 0.25 * pulse)
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(palette.accent))
            } else if hasOpen {
                let r = baseWidth * 0.34
                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                         with: .color(palette.ink.opacity(0.35)))
            }
        }
    }
}

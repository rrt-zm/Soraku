import SwiftUI

enum InkRenderer {
    static func map(_ p: CGPoint, in rect: CGSize, inset: CGFloat) -> CGPoint {
        CGPoint(x: inset + p.x * (rect.width - inset * 2),
                y: inset + p.y * (rect.height - inset * 2))
    }

    static func smoothCenterline(_ pts: [CGPoint], samplesPerSegment: Int) -> [CGPoint] {
        guard pts.count >= 2 else { return pts }
        if pts.count == 2 {
            return (0...samplesPerSegment).map { i in
                let t = CGFloat(i) / CGFloat(samplesPerSegment)
                return CGPoint(x: pts[0].x + (pts[1].x - pts[0].x) * t,
                               y: pts[0].y + (pts[1].y - pts[0].y) * t)
            }
        }
        var result: [CGPoint] = []
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = pts[min(pts.count - 1, i + 2)]
            let steps = i == pts.count - 2 ? samplesPerSegment : samplesPerSegment
            for s in 0..<steps {
                let t = CGFloat(s) / CGFloat(samplesPerSegment)
                result.append(catmullRom(p0, p1, p2, p3, t))
            }
        }
        result.append(pts.last!)
        return result
    }

    private static func catmullRom(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        let x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
        let y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
        return CGPoint(x: x, y: y)
    }

    static func ribbon(centerline pts: [CGPoint], maxWidth: CGFloat, taperEnd: Bool) -> Path {
        guard pts.count >= 2 else { return Path() }
        let n = pts.count
        var left: [CGPoint] = []
        var right: [CGPoint] = []
        for i in 0..<n {
            let prev = pts[max(0, i - 1)]
            let next = pts[min(n - 1, i + 1)]
            var tx = next.x - prev.x
            var ty = next.y - prev.y
            let len = max(0.0001, (tx * tx + ty * ty).squareRoot())
            tx /= len; ty /= len
            let nx = -ty, ny = tx
            let t = CGFloat(i) / CGFloat(n - 1)
            let w = widthProfile(t, maxWidth: maxWidth, taperEnd: taperEnd, index: i) / 2
            left.append(CGPoint(x: pts[i].x + nx * w, y: pts[i].y + ny * w))
            right.append(CGPoint(x: pts[i].x - nx * w, y: pts[i].y - ny * w))
        }
        var path = Path()
        path.move(to: left[0])
        for p in left.dropFirst() { path.addLine(to: p) }
        for p in right.reversed() { path.addLine(to: p) }
        path.closeSubpath()
        return path
    }

    private static func widthProfile(_ t: CGFloat, maxWidth: CGFloat, taperEnd: Bool, index: Int) -> CGFloat {
        let k: CGFloat = 0.16
        var p: CGFloat = 1
        p *= smooth(min(1, t / k))
        if taperEnd { p *= smooth(min(1, (1 - t) / k)) }
        let floorP: CGFloat = 0.14
        p = floorP + (1 - floorP) * p
        let wobble = 0.92 + 0.12 * CGFloat(sin(Double(index) * 1.7))
        return maxWidth * p * wobble
    }

    private static func smooth(_ x: CGFloat) -> CGFloat {
        let c = max(0, min(1, x))
        return c * c * (3 - 2 * c)
    }

    static func drawStroke(_ ctx: inout GraphicsContext, nodePoints: [CGPoint], color: Color, richness: Double, baseWidth: CGFloat, taperEnd: Bool, bleed: Bool) {
        guard nodePoints.count >= 2 else { return }
        let centerline = smoothCenterline(nodePoints, samplesPerSegment: 10)
        if bleed {
            var bleedCtx = ctx
            bleedCtx.addFilter(.blur(radius: baseWidth * 0.6))
            var line = Path()
            line.move(to: centerline[0])
            for p in centerline.dropFirst() { line.addLine(to: p) }
            bleedCtx.stroke(line, with: .color(color.opacity(0.18 * richness)), style: StrokeStyle(lineWidth: baseWidth * 1.7, lineCap: .round, lineJoin: .round))
        }
        let ribbonPath = ribbon(centerline: centerline, maxWidth: baseWidth, taperEnd: taperEnd)
        ctx.fill(ribbonPath, with: .color(color.opacity(0.55 + 0.45 * richness)))
    }

    static func blotPath(center: CGPoint, radius: CGFloat, seed: UInt64) -> Path {
        var rng = SeededGenerator(seed: seed)
        var path = Path()
        let lobes = 9
        for i in 0...lobes {
            let angle = Double(i) / Double(lobes) * 2 * .pi
            let r = radius * (0.7 + rng.unit() * 0.6)
            let p = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

import SwiftUI

struct AppBackground: View {
    var palette: Palette
    var reducedMotion: Bool
    var motes: Bool = true

    var body: some View {
        ZStack {
            LinearGradient(colors: palette.background, startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if motes {
                DriftingMotes(palette: palette, reducedMotion: reducedMotion)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
    }
}

struct DriftingMotes: View {
    var palette: Palette
    var reducedMotion: Bool

    private struct Mote { let x: Double; let y: Double; let r: Double; let speed: Double; let drift: Double }

    private let seeds: [Mote] = {
        var rng = SeededGenerator(seed: 8821)
        return (0..<26).map { _ in
            Mote(x: rng.unit(), y: rng.unit(), r: 1.2 + rng.unit() * 3.4,
                 speed: 0.01 + rng.unit() * 0.03, drift: rng.unit() * 2 * .pi)
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 1 : 1.0 / 30.0)) { timeline in
            Canvas { ctx, size in
                let t = reducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                for mote in seeds {
                    let progress = (mote.y - t * mote.speed).truncatingRemainder(dividingBy: 1)
                    let y = (progress < 0 ? progress + 1 : progress) * size.height
                    let x = (mote.x + sin(t * 0.2 + mote.drift) * 0.02) * size.width
                    let rect = CGRect(x: x, y: y, width: mote.r, height: mote.r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(palette.ink.opacity(0.05)))
                }
            }
        }
    }
}

struct PaperSheet: View {
    var palette: Palette
    var cornerRadius: CGFloat = Radius.l

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(palette.paper)
            PaperGrain(color: palette.paperGrain)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    RadialGradient(colors: [Color.clear, palette.ink.opacity(palette.isDark ? 0.18 : 0.07)],
                                   center: .center, startRadius: 80, endRadius: 460)
                )
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(palette.ink.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: palette.ink.opacity(palette.isDark ? 0.5 : 0.18), radius: 22, x: 0, y: 14)
    }
}

struct PaperGrain: View {
    var color: Color

    private let dots: [(Double, Double, Double)] = {
        var rng = SeededGenerator(seed: 4471)
        return (0..<220).map { _ in (rng.unit(), rng.unit(), 0.4 + rng.unit() * 1.1) }
    }()

    var body: some View {
        Canvas { ctx, size in
            for dot in dots {
                let rect = CGRect(x: dot.0 * size.width, y: dot.1 * size.height, width: dot.2, height: dot.2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
    }
}

struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
    mutating func unit() -> Double { Double(next() % 100000) / 100000.0 }
}

import SwiftUI

struct BreathBar: View {
    var engine: LevelEngine
    var palette: Palette
    var reducedMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: reducedMotion ? 0.2 : 1.0 / 40.0)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let phase = reducedMotion ? 0.5 : engine.breathPhase(elapsed: elapsed)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.ink.opacity(0.10))
                    Capsule()
                        .fill(palette.breath.opacity(0.16))
                        .frame(width: w * 0.34)
                        .offset(x: w * 0.33)
                    Circle()
                        .fill(palette.breath)
                        .frame(width: 16, height: 16)
                        .offset(x: (w - 16) * phase)
                        .shadow(color: palette.breath.opacity(0.5), radius: 6)
                }
            }
            .frame(height: 16)
            .overlay(alignment: .topLeading) {
                Text(phase < 0.5 ? "Inhale" : "Exhale")
                    .font(.label(11))
                    .foregroundStyle(palette.textSecondary)
                    .offset(y: -18)
            }
        }
        .frame(height: 16)
    }
}

struct StrokeBudgetView: View {
    var used: Int
    var required: Int
    var palette: Palette
    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<required, id: \.self) { i in
                Capsule()
                    .fill(i < (required - used) ? palette.accent : palette.ink.opacity(0.15))
                    .frame(width: 18, height: 6)
            }
        }
    }
}

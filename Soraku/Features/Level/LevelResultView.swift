import SwiftUI

struct LevelResultView: View {
    let result: LevelRunResult
    let level: LevelDefinition
    var palette: Palette
    var reducedMotion: Bool
    var onRetry: () -> Void
    var onNext: () -> Void
    var onExit: () -> Void

    @State private var sealIn = false
    @State private var starsShown = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
                .onTapGesture { }
            InkPanel(palette: palette) {
                VStack(spacing: Spacing.l) {
                    if result.cleared {
                        clearedContent
                    } else {
                        failedContent
                    }
                }
                .frame(maxWidth: 340)
            }
            .padding(Spacing.l)
        }
        .onAppear { animateIn() }
    }

    private var clearedContent: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                Circle().fill(palette.vermilion.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "seal.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(palette.vermilion)
                    .scaleEffect(sealIn ? 1 : 1.8)
                    .opacity(sealIn ? 1 : 0)
                    .rotationEffect(.degrees(sealIn ? 0 : -18))
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: "F6EFDE"))
                    .opacity(sealIn ? 1 : 0)
            }
            Text("Sealed").font(.display(26)).foregroundStyle(palette.textPrimary)
            StarRow(count: starsShown, size: 26, palette: palette)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: starsShown)

            VStack(spacing: Spacing.s) {
                goalLine("Glyph completed", met: true)
                goalLine("Without a blot", met: result.blotCount == 0)
                goalLine("Within the breath", met: result.calmRatio >= level.starThresholds.calmBreathRatio)
            }

            HStack(spacing: 6) {
                Image(systemName: "drop.fill").foregroundStyle(palette.accent).font(.system(size: 14))
                Text("+\(result.reward) ink").font(.numeric(16)).foregroundStyle(palette.textPrimary)
            }
            .padding(.top, 2)

            VStack(spacing: Spacing.s) {
                SorakuButton(title: "Next Glyph", icon: "arrow.right", kind: .primary, palette: palette, action: onNext)
                HStack(spacing: Spacing.s) {
                    SorakuButton(title: "Retry", kind: .secondary, palette: palette, action: onRetry)
                    SorakuButton(title: "Map", kind: .secondary, palette: palette, action: onExit)
                }
            }
        }
    }

    private var failedContent: some View {
        VStack(spacing: Spacing.m) {
            ZStack {
                Circle().fill(palette.ink.opacity(0.08)).frame(width: 92, height: 92)
                Image(systemName: "drop.fill").font(.system(size: 44)).foregroundStyle(palette.ink.opacity(0.5))
            }
            Text("The ink ran out").font(.display(24)).foregroundStyle(palette.textPrimary)
            Text("This glyph rests in \(level.requiredStrokes) stroke\(level.requiredStrokes == 1 ? "" : "s"). Breathe, and trace again.")
                .font(.body(14)).foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: Spacing.s) {
                SorakuButton(title: "Try Again", icon: "arrow.counterclockwise", kind: .primary, palette: palette, action: onRetry)
                SorakuButton(title: "Back to Map", kind: .secondary, palette: palette, action: onExit)
            }
            .padding(.top, Spacing.s)
        }
    }

    private func goalLine(_ text: String, met: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            Image(systemName: met ? "seal.fill" : "seal")
                .foregroundStyle(met ? palette.star : palette.textSecondary.opacity(0.5))
                .font(.system(size: 14))
            Text(text).font(.body(14)).foregroundStyle(met ? palette.textPrimary : palette.textSecondary)
            Spacer()
        }
    }

    private func animateIn() {
        if reducedMotion {
            sealIn = true
            starsShown = result.stars
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.55).delay(0.1)) { sealIn = true }
        for i in 1...max(1, result.stars) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.18) {
                if i <= result.stars { starsShown = i }
            }
        }
    }
}

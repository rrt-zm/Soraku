import SwiftUI

struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.palette) private var palette

    @State private var step = 0
    @State private var practiceEngine: LevelEngine?

    private let pages: [OnboardingPage] = [
        OnboardingPage(icon: "paintbrush.pointed", title: "Soraku", body: "A quiet game of calligraphy. Each glyph waits on the paper to be traced in a single, unbroken breath."),
        OnboardingPage(icon: "scribble.variable", title: "One Stroke", body: "Press a glowing point and drag along the ghostly lines. Cover every line without lifting your finger across already-inked ones."),
        OnboardingPage(icon: "wind", title: "The Breath", body: "A rhythm bar marks the ideal pace. Move with it: rush, and the line tears into a blot; flow, and the ink stays rich."),
        OnboardingPage(icon: "rectangle.split.3x1", title: "Exact Strokes", body: "Each glyph names how many strokes it should take. Lift to begin a new stroke — but spend them wisely, the budget is exact."),
    ]

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            VStack(spacing: Spacing.l) {
                Spacer(minLength: Spacing.l)
                if step < pages.count {
                    infoPage(pages[step])
                } else {
                    practicePage
                }
                Spacer()
                dots
                controls
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xl)
        }
    }

    private func infoPage(_ page: OnboardingPage) -> some View {
        VStack(spacing: Spacing.l) {
            ZStack {
                Circle().fill(palette.accent.opacity(0.12)).frame(width: 130, height: 130)
                Image(systemName: page.icon).font(.system(size: 56, weight: .light)).foregroundStyle(palette.accent)
                    .breathingScale(active: true, reduced: store.settings.reducedMotion, amount: 0.04)
            }
            Text(page.title).font(.display(34)).foregroundStyle(palette.textPrimary)
            Text(page.body).font(.body(16)).foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .transition(.opacity)
    }

    private var practicePage: some View {
        VStack(spacing: Spacing.m) {
            Text("Your First Glyph").font(.display(28)).foregroundStyle(palette.textPrimary)
            Text(practiceEngine?.status == .cleared ? "Beautifully done." : "Trace all three lines in one stroke.")
                .font(.body(15)).foregroundStyle(practiceEngine?.status == .cleared ? palette.accent : palette.textSecondary)
            ZStack {
                PaperSheet(palette: palette)
                if let practiceEngine {
                    LevelCanvas(engine: practiceEngine, palette: palette, reducedMotion: store.settings.reducedMotion)
                        .padding(4)
                }
            }
            .frame(width: 280, height: 280)
        }
        .onAppear { buildPractice() }
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(0...pages.count, id: \.self) { i in
                Circle().fill(i == step ? palette.accent : palette.ink.opacity(0.18))
                    .frame(width: i == step ? 9 : 7, height: i == step ? 9 : 7)
            }
        }
    }

    private var controls: some View {
        VStack(spacing: Spacing.s) {
            if step < pages.count {
                SorakuButton(title: "Continue", icon: "arrow.right", kind: .primary, palette: palette) {
                    withAnimation(.easeInOut(duration: Durations.gentle)) { step += 1 }
                }
                Button("Skip") { store.completeOnboarding() }
                    .font(.label(14)).foregroundStyle(palette.textSecondary)
            } else {
                SorakuButton(title: "Enter the Studio", icon: "checkmark", kind: .primary, palette: palette, enabled: practiceEngine?.status == .cleared) {
                    store.completeOnboarding()
                }
                Button("Skip for now") { store.completeOnboarding() }
                    .font(.label(14)).foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func buildPractice() {
        guard practiceEngine == nil else { return }
        let level = store.content.levels.first { $0.requiredStrokes == 1 && $0.segments.count == 3 }
            ?? store.content.levels.first
        guard let level else { return }
        let e = LevelEngine(level: level)
        e.onBrush = { store.audio.playBrush() }
        e.onTraverse = { store.haptics.play(.light) }
        practiceEngine = e
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let body: String
}

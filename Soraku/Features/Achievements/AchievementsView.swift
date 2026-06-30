import SwiftUI

struct AchievementsView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            ScrollView {
                VStack(spacing: Spacing.m) {
                    ScreenHeader(title: "Achievements", subtitle: "\(unlockedCount)/\(store.content.achievements.count) earned", palette: palette, onBack: { router.pop() }, trailing: nil)
                        .padding(.top, Spacing.m)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)], spacing: Spacing.m) {
                        ForEach(Array(store.achievementStates().enumerated()), id: \.element.id) { index, ach in
                            achievementCard(ach, index: index)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { appeared = true } }
    }

    private var unlockedCount: Int { store.achievementStates().filter { $0.unlocked }.count }

    private func achievementCard(_ ach: AchievementState, index: Int) -> some View {
        InkPanel(palette: palette, padding: Spacing.m) {
            VStack(spacing: Spacing.s) {
                ZStack {
                    Circle().fill(ach.unlocked ? palette.accent.opacity(0.16) : palette.ink.opacity(0.06)).frame(width: 56, height: 56)
                    Image(systemName: ach.unlocked ? "rosette" : "lock.fill")
                        .font(.system(size: ach.unlocked ? 26 : 18, weight: .light))
                        .foregroundStyle(ach.unlocked ? palette.accent : palette.textSecondary.opacity(0.6))
                        .scaleEffect(appeared && ach.unlocked ? 1 : 0.7)
                }
                Text(ach.definition.title).font(.title(15)).foregroundStyle(palette.textPrimary).multilineTextAlignment(.center).lineLimit(2).frame(height: 38)
                Text(ach.definition.detail).font(.body(11)).foregroundStyle(palette.textSecondary).multilineTextAlignment(.center).lineLimit(2).frame(height: 28, alignment: .top)
                if ach.unlocked {
                    Tag(text: "Earned", palette: palette, filled: true)
                } else {
                    ProgressBead(fraction: ach.fraction, palette: palette)
                    Text("\(min(ach.progress, ach.definition.target))/\(ach.definition.target)").font(.numeric(11)).foregroundStyle(palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

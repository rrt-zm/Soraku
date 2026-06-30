import SwiftUI

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    header
                    continueCard
                    grid
                }
                .padding(.horizontal, Spacing.l)
                .padding(.top, Spacing.m)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Soraku").font(.display(40)).foregroundStyle(palette.textPrimary)
                    .breathingScale(active: true, reduced: store.settings.reducedMotion, amount: 0.012)
                Text("One breath, one stroke.").font(.body(15)).foregroundStyle(palette.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.s) {
                CurrencyPill(amount: store.currency, palette: palette)
                HStack(spacing: 5) {
                    Image(systemName: "seal.fill").font(.system(size: 12)).foregroundStyle(palette.star)
                    Text("\(store.totalStars)").font(.numeric(15)).foregroundStyle(palette.textPrimary)
                }
            }
        }
        .padding(.top, Spacing.l)
    }

    @ViewBuilder
    private var continueCard: some View {
        if let level = store.nextPlayableLevel(), let chapter = store.content.chaptersById[level.chapterId] {
            Button {
                router.launch(LevelLaunch(levelId: level.id, mode: .campaign))
            } label: {
                InkPanel(palette: palette) {
                    HStack(spacing: Spacing.l) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.m, style: .continuous)
                                .fill(palette.paper)
                                .frame(width: 78, height: 78)
                            GlyphThumbnail(level: level, palette: palette, lineColor: palette.ink)
                                .frame(width: 64, height: 64)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.stars(for: level.id) > 0 ? "Continue" : "Begin")
                                .font(.label(13)).foregroundStyle(palette.accent)
                            Text(level.name).font(.display(22)).foregroundStyle(palette.textPrimary)
                            Text(chapter.title).font(.body(13)).foregroundStyle(palette.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "play.fill").font(.system(size: 22)).foregroundStyle(palette.accent)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)], spacing: Spacing.m) {
            hubCard("Scrolls", "scroll", subtitle: "\(store.chapters.filter { store.isChapterUnlocked($0) }.count) open") { router.push(.scrollMap) }
            hubCard("Daily Glyph", "sun.max", subtitle: dailySubtitle) { router.push(.daily) }
            hubCard("Free Ink", "paintbrush.pointed", subtitle: "Zen") { router.zenActive = true }
            hubCard("Collection", "circle.grid.2x2", subtitle: "\(store.snapshot.unlockedCosmetics.count) owned") { router.push(.cosmetics) }
            hubCard("Quests", "flag", subtitle: questSubtitle) { router.push(.quests) }
            hubCard("Achievements", "rosette", subtitle: "\(store.achievementStates().filter { $0.unlocked }.count)/\(store.content.achievements.count)") { router.push(.achievements) }
            hubCard("Statistics", "chart.bar", subtitle: "Lifetime") { router.push(.statistics) }
            hubCard("Settings", "slider.horizontal.3", subtitle: nil) { router.push(.settings) }
        }
    }

    private var dailySubtitle: String {
        let key = ContentRepository.dayKey(Date())
        return store.dailyStars(key) > 0 ? "Done today" : "New today"
    }

    private var questSubtitle: String {
        let claimable = store.questStates().filter { $0.isComplete && !$0.claimed }.count
        return claimable > 0 ? "\(claimable) to claim" : "Ongoing"
    }

    private func hubCard(_ title: String, _ icon: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            InkPanel(palette: palette, padding: Spacing.m) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Image(systemName: icon).font(.system(size: 24, weight: .light)).foregroundStyle(palette.accent)
                    Spacer(minLength: Spacing.m)
                    Text(title).font(.title(18)).foregroundStyle(palette.textPrimary)
                    if let subtitle {
                        Text(subtitle).font(.label(12)).foregroundStyle(palette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct GlyphThumbnail: View {
    let level: LevelDefinition
    var palette: Palette
    var lineColor: Color
    var solved: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let inset = size.width * 0.12
            for seg in level.segments {
                guard let a = level.nodes.first(where: { $0.id == seg.a })?.point,
                      let b = level.nodes.first(where: { $0.id == seg.b })?.point else { continue }
                let pa = CGPoint(x: inset + a.x * (size.width - inset * 2), y: inset + a.y * (size.height - inset * 2))
                let pb = CGPoint(x: inset + b.x * (size.width - inset * 2), y: inset + b.y * (size.height - inset * 2))
                var path = Path()
                path.move(to: pa); path.addLine(to: pb)
                let color = seg.color == .black ? lineColor : palette.ink(for: seg.color)
                ctx.stroke(path, with: .color(color.opacity(solved ? 0.9 : 0.65)), style: StrokeStyle(lineWidth: size.width * 0.045, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

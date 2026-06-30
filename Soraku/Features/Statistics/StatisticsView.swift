import SwiftUI

struct StatisticsView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    ScreenHeader(title: "Statistics", subtitle: "The record of your hand", palette: palette, onBack: { router.pop() }, trailing: nil)
                        .padding(.top, Spacing.m)

                    tiles
                    chapterChart
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func m(_ metric: Metric) -> Int { store.snapshot.metric(metric) }

    private var tiles: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: Spacing.m), GridItem(.flexible(), spacing: Spacing.m)], spacing: Spacing.m) {
            statTile("Glyphs Traced", "\(m(.glyphsTraced))", "scribble.variable")
            statTile("Stars Earned", "\(store.totalStars)", "seal.fill")
            statTile("Chapters Cleared", "\(m(.chaptersCleared))", "scroll")
            statTile("Perfect Strokes", "\(m(.perfectStrokes))", "checkmark.seal")
            statTile("Calm Breaths", "\(m(.calmBreaths))", "wind")
            statTile("Blot-Free Glyphs", "\(m(.blotFreeGlyphs))", "drop")
            statTile("Total Strokes", "\(m(.totalStrokes))", "paintbrush.pointed")
            statTile("Daily Glyphs", "\(m(.dailyCompleted))", "sun.max")
            statTile("Free Ink", timeString(m(.zenSeconds)), "leaf")
            statTile("Time Played", timeString(m(.timePlayedSeconds)), "hourglass")
        }
    }

    private func statTile(_ title: String, _ value: String, _ icon: String) -> some View {
        InkPanel(palette: palette, padding: Spacing.m) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Image(systemName: icon).font(.system(size: 18, weight: .light)).foregroundStyle(palette.accent)
                Text(value).font(.numeric(24)).foregroundStyle(palette.textPrimary)
                Text(title).font(.label(12)).foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chapterChart: some View {
        InkPanel(palette: palette) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text("Stars by Scroll").font(.title(18)).foregroundStyle(palette.textPrimary)
                let maxStars = Double(store.chapters.map { $0.levelIds.count * 3 }.max() ?? 1)
                ForEach(store.chapters) { chapter in
                    let stars = Double(store.chapterStars(chapter))
                    let total = Double(chapter.levelIds.count * 3)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(chapter.title).font(.body(13)).foregroundStyle(palette.textSecondary)
                            Spacer()
                            Text("\(Int(stars))/\(Int(total))").font(.numeric(12)).foregroundStyle(palette.textSecondary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(palette.ink.opacity(0.08))
                                Capsule().fill(store.isChapterUnlocked(chapter) ? palette.accent : palette.ink.opacity(0.2))
                                    .frame(width: max(4, geo.size.width * (stars / max(1, maxStars))))
                            }
                        }
                        .frame(height: 10)
                    }
                }
            }
        }
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }
}

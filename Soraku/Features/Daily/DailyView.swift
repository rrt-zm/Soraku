import SwiftUI

struct DailyView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette

    private var today: Date { Date() }
    private var dayKey: String { ContentRepository.dayKey(today) }
    private var level: LevelDefinition { ContentRepository.shared.dailyLevel(for: today) }

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    ScreenHeader(title: "Daily Glyph", subtitle: dayKey, palette: palette, onBack: { router.pop() }, trailing: nil)
                        .padding(.top, Spacing.m)

                    InkPanel(palette: palette) {
                        VStack(spacing: Spacing.m) {
                            ZStack {
                                RoundedRectangle(cornerRadius: Radius.l, style: .continuous).fill(palette.paper)
                                GlyphThumbnail(level: level, palette: palette, lineColor: palette.ink, solved: store.dailyStars(dayKey) > 0)
                                    .padding(Spacing.l)
                            }
                            .frame(height: 220)

                            HStack {
                                Tag(text: level.mechanic.title, palette: palette)
                                Spacer()
                                StarRow(count: store.dailyStars(dayKey), size: 18, palette: palette)
                            }

                            if store.dailyStars(dayKey) > 0 {
                                Text("Today's glyph is sealed. Return tomorrow for a new one.")
                                    .font(.body(13)).foregroundStyle(palette.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                SorakuButton(title: "Trace Again", icon: "arrow.counterclockwise", kind: .secondary, palette: palette) {
                                    router.launch(LevelLaunch(levelId: level.id, mode: .daily(dayKey)))
                                }
                            } else {
                                SorakuButton(title: "Begin Today's Glyph", icon: "play.fill", kind: .primary, palette: palette) {
                                    router.launch(LevelLaunch(levelId: level.id, mode: .daily(dayKey)))
                                }
                            }
                        }
                    }

                    historyStrip
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var historyStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Recent Mornings").font(.title(17)).foregroundStyle(palette.textPrimary)
            HStack(spacing: Spacing.s) {
                ForEach(recentDays(), id: \.self) { key in
                    let stars = store.dailyStars(key)
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: Radius.s).fill(palette.panel)
                            if stars > 0 {
                                Image(systemName: "seal.fill").foregroundStyle(palette.star).font(.system(size: 14))
                            } else {
                                Image(systemName: "circle.dotted").foregroundStyle(palette.textSecondary.opacity(0.4)).font(.system(size: 14))
                            }
                        }
                        .frame(width: 40, height: 40)
                        Text(String(key.suffix(2))).font(.label(11)).foregroundStyle(palette.textSecondary)
                    }
                }
            }
        }
    }

    private func recentDays() -> [String] {
        let cal = Calendar(identifier: .gregorian)
        return (0..<7).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today).map { ContentRepository.dayKey($0) }
        }
    }
}

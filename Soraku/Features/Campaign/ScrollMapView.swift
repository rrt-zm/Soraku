import SwiftUI

struct ScrollMapView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.l) {
                    ScreenHeader(title: "The Scrolls", subtitle: "\(store.totalStars) stars gathered", palette: palette, onBack: { router.pop() }, trailing: AnyView(CurrencyPill(amount: store.currency, palette: palette)))
                        .padding(.top, Spacing.m)

                    VStack(spacing: 0) {
                        ForEach(Array(store.chapters.enumerated()), id: \.element.id) { index, chapter in
                            chapterRow(chapter, isLast: index == store.chapters.count - 1)
                        }
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func chapterRow(_ chapter: ChapterDefinition, isLast: Bool) -> some View {
        let unlocked = store.isChapterUnlocked(chapter)
        let stars = store.chapterStars(chapter)
        let maxStars = chapter.levelIds.count * 3
        let cleared = store.chapterCleared(chapter)
        return HStack(alignment: .top, spacing: Spacing.m) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(unlocked ? palette.accent : palette.ink.opacity(0.18)).frame(width: 18, height: 18)
                    if cleared {
                        Image(systemName: "seal.fill").font(.system(size: 10)).foregroundStyle(palette.paper)
                    }
                }
                if !isLast {
                    Rectangle().fill(palette.ink.opacity(0.18)).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 18)

            Button {
                if unlocked { router.push(.chapter(chapter.id)) }
            } label: {
                InkPanel(palette: palette, padding: Spacing.m) {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack {
                            Text(chapter.title).font(.display(20)).foregroundStyle(unlocked ? palette.textPrimary : palette.textSecondary)
                            Spacer()
                            if unlocked {
                                Image(systemName: "chevron.right").foregroundStyle(palette.textSecondary).font(.system(size: 13, weight: .semibold))
                            } else {
                                Image(systemName: "lock.fill").foregroundStyle(palette.textSecondary).font(.system(size: 13))
                            }
                        }
                        Text(chapter.subtitle).font(.body(13)).foregroundStyle(palette.textSecondary)
                        HStack(spacing: Spacing.s) {
                            Tag(text: chapter.mechanic.title, palette: palette, filled: false)
                            if unlocked {
                                HStack(spacing: 4) {
                                    Image(systemName: "seal.fill").font(.system(size: 11)).foregroundStyle(palette.star)
                                    Text("\(stars)/\(maxStars)").font(.numeric(12)).foregroundStyle(palette.textSecondary)
                                }
                            } else {
                                Text("\(chapter.unlockStars) stars to open").font(.label(12)).foregroundStyle(palette.textSecondary)
                            }
                        }
                        if unlocked {
                            ProgressBead(fraction: Double(stars) / Double(max(1, maxStars)), palette: palette)
                                .padding(.top, 2)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(!unlocked)
            .padding(.bottom, Spacing.m)
        }
    }
}

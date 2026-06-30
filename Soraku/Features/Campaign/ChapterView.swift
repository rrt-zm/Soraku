import SwiftUI

struct ChapterView: View {
    let chapterId: String
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette
    @State private var showIntro = false

    private var chapter: ChapterDefinition? { store.content.chaptersById[chapterId] }

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            if let chapter {
                content(chapter)
                if showIntro {
                    ChapterIntroOverlay(chapter: chapter, palette: palette) {
                        withAnimation(.easeInOut(duration: Durations.gentle)) { showIntro = false }
                        store.markIntroSeen(chapter)
                    }
                    .transition(.opacity)
                }
            } else {
                EmptyStateView(icon: "scroll", title: "Lost scroll", message: "This chapter could not be found.", palette: palette)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if let chapter, !store.hasSeenIntro(chapter) { showIntro = true }
        }
    }

    private func content(_ chapter: ChapterDefinition) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                ScreenHeader(title: chapter.title, subtitle: chapter.subtitle, palette: palette, onBack: { router.pop() }, trailing: AnyView(CurrencyPill(amount: store.currency, palette: palette)))
                    .padding(.top, Spacing.m)

                Tag(text: chapter.mechanic.title, palette: palette, filled: true)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: Spacing.m)], spacing: Spacing.m) {
                    ForEach(store.levels(in: chapter)) { level in
                        levelCell(level)
                    }
                }
            }
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.xxl)
        }
    }

    private func levelCell(_ level: LevelDefinition) -> some View {
        let unlocked = store.isLevelUnlocked(level)
        let stars = store.stars(for: level.id)
        return Button {
            if unlocked { router.launch(LevelLaunch(levelId: level.id, mode: .campaign)) }
        } label: {
            VStack(spacing: Spacing.s) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.m, style: .continuous).fill(palette.paper)
                    if unlocked {
                        GlyphThumbnail(level: level, palette: palette, lineColor: palette.ink, solved: stars > 0)
                            .padding(Spacing.s)
                    } else {
                        Image(systemName: "lock.fill").foregroundStyle(palette.textSecondary.opacity(0.6))
                    }
                }
                .frame(height: 92)
                .overlay(RoundedRectangle(cornerRadius: Radius.m, style: .continuous).strokeBorder(palette.panelEdge.opacity(0.5), lineWidth: 1))

                Text(level.name).font(.label(12)).foregroundStyle(palette.textPrimary).lineLimit(1)
                StarRow(count: stars, size: 11, palette: palette)
            }
            .opacity(unlocked ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

struct ChapterIntroOverlay: View {
    let chapter: ChapterDefinition
    var palette: Palette
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            InkPanel(palette: palette) {
                VStack(spacing: Spacing.m) {
                    Image(systemName: "scroll").font(.system(size: 40, weight: .light)).foregroundStyle(palette.accent)
                    Text(chapter.title).font(.display(26)).foregroundStyle(palette.textPrimary)
                    Text(chapter.subtitle).font(.body(15)).foregroundStyle(palette.textSecondary).multilineTextAlignment(.center)
                    Divider().background(palette.panelEdge)
                    Text(chapter.mechanic.title).font(.title(17)).foregroundStyle(palette.accent)
                    Text(chapter.mechanic.lesson).font(.body(14)).foregroundStyle(palette.textSecondary).multilineTextAlignment(.center)
                    SorakuButton(title: "Begin", kind: .primary, palette: palette, action: onDismiss)
                        .padding(.top, Spacing.s)
                }
                .frame(maxWidth: 320)
            }
            .padding(Spacing.l)
        }
    }
}

import SwiftUI

struct QuestsView: View {
    @Environment(GameStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.palette) private var palette
    @State private var toast: String?

    var body: some View {
        ZStack {
            AppBackground(palette: palette, reducedMotion: store.settings.reducedMotion)
            ScrollView {
                VStack(spacing: Spacing.m) {
                    ScreenHeader(title: "Quests", subtitle: "Gentle goals along the way", palette: palette, onBack: { router.pop() }, trailing: AnyView(CurrencyPill(amount: store.currency, palette: palette)))
                        .padding(.top, Spacing.m)
                    ForEach(store.questStates()) { quest in
                        questCard(quest)
                    }
                }
                .padding(.horizontal, Spacing.l)
                .padding(.bottom, Spacing.xxl)
            }
            if let toast {
                VStack { Spacer(); ToastView(text: toast, icon: "drop.fill", palette: palette).padding(.bottom, Spacing.xxl) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func questCard(_ quest: QuestState) -> some View {
        InkPanel(palette: palette) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(quest.definition.title).font(.title(17)).foregroundStyle(palette.textPrimary)
                        Text(quest.definition.detail).font(.body(13)).foregroundStyle(palette.textSecondary)
                    }
                    Spacer()
                    if quest.claimed {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(palette.star).font(.system(size: 22))
                    }
                }
                ProgressBead(fraction: quest.fraction, palette: palette)
                HStack {
                    Text("\(min(quest.progress, quest.definition.target))/\(quest.definition.target)")
                        .font(.numeric(13)).foregroundStyle(palette.textSecondary)
                    Spacer()
                    if quest.claimed {
                        Text("Claimed").font(.label(13)).foregroundStyle(palette.textSecondary)
                    } else if quest.isComplete {
                        Button {
                            if store.claimQuest(quest) { flash("+\(quest.definition.reward) ink") }
                        } label: {
                            Text("Claim +\(quest.definition.reward)")
                                .font(.label(13))
                                .foregroundStyle(palette.isDark ? Color(hex: "120F0A") : Color(hex: "F6EFDE"))
                                .padding(.horizontal, Spacing.m).padding(.vertical, 7)
                                .background(Capsule().fill(palette.accent))
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill").font(.system(size: 11)).foregroundStyle(palette.accent)
                            Text("\(quest.definition.reward)").font(.numeric(13)).foregroundStyle(palette.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private func flash(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.4)) { toast = nil }
        }
    }
}

import SwiftUI

struct RootView: View {
    @State private var store = GameStore()
    @State private var router = AppRouter()
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.scenePhase) private var scenePhase

    private var palette: Palette {
        Palette.resolve(
            theme: store.settings.theme,
            systemDark: systemScheme == .dark,
            paperTone: store.equipped(.paper)?.tone ?? "F2E9D8",
            inkSwatch: store.equipped(.ink)?.swatch ?? "0E0D0B",
            accentHex: store.equipped(.theme)?.accent ?? "C8442E"
        )
    }

    var body: some View {
        ZStack {
            if store.snapshot.onboardingComplete {
                NavigationStack(path: $router.path) {
                    HomeView()
                        .navigationDestination(for: HubRoute.self) { route in
                            destination(route)
                                .navigationBarBackButtonHidden(true)
                        }
                }
                .tint(palette.accent)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .environment(store)
        .environment(router)
        .environment(\.palette, palette)
        .preferredColorScheme(preferredScheme)
        .fullScreenCover(item: $router.activeLevel) { launch in
            LevelView(launch: launch)
                .environment(store)
                .environment(router)
                .environment(\.palette, palette)
                .preferredColorScheme(preferredScheme)
        }
        .fullScreenCover(isPresented: $router.zenActive) {
            ZenView()
                .environment(store)
                .environment(router)
                .environment(\.palette, palette)
                .preferredColorScheme(preferredScheme)
        }
        .onAppear { store.bootstrap(); applyDemoHook() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive { store.persist() }
        }
        .animation(.easeInOut(duration: Durations.gentle), value: store.snapshot.onboardingComplete)
    }

    private func applyDemoHook() {
        let env = ProcessInfo.processInfo.environment
        guard env["SORAKU_DEMO"] != nil else { return }
        if env["SORAKU_ONBOARD"] == nil { store.completeOnboarding() }
        if let route = env["SORAKU_ROUTE"] {
            switch route {
            case "scrollMap": router.path = [.scrollMap]
            case "chapter": router.path = [.scrollMap, .chapter("C1")]
            case "cosmetics": router.path = [.cosmetics]
            case "quests": router.path = [.quests]
            case "achievements": router.path = [.achievements]
            case "statistics": router.path = [.statistics]
            case "settings": router.path = [.settings]
            case "daily": router.path = [.daily]
            case "zen": router.zenActive = true
            default: break
            }
        }
        if let level = env["SORAKU_LEVEL"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                router.launch(LevelLaunch(levelId: level, mode: .campaign))
            }
        }
    }

    private var preferredScheme: ColorScheme? {
        switch store.settings.theme {
        case .day: return .light
        case .night: return .dark
        case .system: return nil
        }
    }

    @ViewBuilder
    private func destination(_ route: HubRoute) -> some View {
        switch route {
        case .scrollMap: ScrollMapView()
        case .chapter(let id): ChapterView(chapterId: id)
        case .daily: DailyView()
        case .cosmetics: CosmeticsView()
        case .quests: QuestsView()
        case .achievements: AchievementsView()
        case .statistics: StatisticsView()
        case .settings: SettingsView()
        }
    }
}

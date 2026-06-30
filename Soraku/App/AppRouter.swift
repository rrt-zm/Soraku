import SwiftUI
import Observation

enum LevelMode: Hashable {
    case campaign
    case daily(String)
    case zen
}

struct LevelLaunch: Identifiable, Hashable {
    let id: String
    let levelId: String
    let mode: LevelMode

    init(levelId: String, mode: LevelMode) {
        self.levelId = levelId
        self.mode = mode
        switch mode {
        case .campaign: id = "campaign-\(levelId)"
        case .daily(let key): id = "daily-\(key)-\(levelId)"
        case .zen: id = "zen-\(levelId)"
        }
    }
}

enum HubRoute: Hashable {
    case scrollMap
    case chapter(String)
    case daily
    case cosmetics
    case quests
    case achievements
    case statistics
    case settings
}

@MainActor
@Observable
final class AppRouter {
    var path: [HubRoute] = []
    var activeLevel: LevelLaunch?
    var zenActive = false
    var showTutorial = false

    func push(_ route: HubRoute) { path.append(route) }
    func pop() { if !path.isEmpty { path.removeLast() } }
    func popToRoot() { path.removeAll() }

    func launch(_ launch: LevelLaunch) { activeLevel = launch }
    func closeLevel() { activeLevel = nil }
}

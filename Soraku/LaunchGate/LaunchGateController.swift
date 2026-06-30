import Combine
import Foundation

enum LaunchGatePhase: Equatable {
    case resolving
    case remoteWebShell
    case nativeApp
}

@MainActor
final class LaunchGateController: ObservableObject {
    @Published private(set) var phase: LaunchGatePhase = .resolving

    init() {
        if LaunchGateConfiguration.remoteGateURL == nil {
            phase = .nativeApp
        }
    }

    func handleBlockedMarkerDetected() {
        guard phase != .nativeApp else { return }
        phase = .nativeApp
    }

    func handleRemoteShellReady() {
        if phase == .resolving {
            phase = .remoteWebShell
        }
    }

    func handleGateLoadFailed() {
        phase = .nativeApp
    }
}

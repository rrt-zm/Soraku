import SwiftUI

struct LaunchRouterView: View {
    @StateObject private var launchGate = LaunchGateController()

    var body: some View {
        Group {
            switch launchGate.phase {
            case .resolving, .remoteWebShell:
                if let url = LaunchGateConfiguration.remoteGateURL {
                    LaunchWebView(gate: launchGate, startURL: url)
                } else {
                    RootView()
                }
            case .nativeApp:
                RootView()
            }
        }
    }
}

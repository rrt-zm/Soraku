import SwiftUI

struct LaunchWebView: View {
    @ObservedObject var gate: LaunchGateController
    let startURL: URL

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ConfigurableWebView(
                startURL: startURL,
                blockGateEnabled: true,
                onBlockedIfGate: { gate.handleBlockedMarkerDetected() },
                onGateShellReady: { gate.handleRemoteShellReady() },
                onGateLoadFailed: { gate.handleGateLoadFailed() }
            )
            .ignoresSafeArea(edges: .bottom)
            if gate.phase == .resolving {
                ZStack {
                    Color.black.opacity(0.45).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
        }
    }
}

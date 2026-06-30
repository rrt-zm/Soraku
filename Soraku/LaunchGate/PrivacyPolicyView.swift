import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let url = LaunchGateConfiguration.remoteGateURL {
                    ConfigurableWebView(
                        startURL: url,
                        blockGateEnabled: false,
                        onBlockedIfGate: nil,
                        onGateShellReady: nil,
                        onGateLoadFailed: nil
                    )
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Privacy Policy unavailable")
                            .font(.headline)
                        Text("The privacy policy could not be loaded right now.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

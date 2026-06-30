import SwiftUI
import WebKit

struct ConfigurableWebView: UIViewRepresentable {
    let startURL: URL
    let blockGateEnabled: Bool
    var onBlockedIfGate: (() -> Void)?
    var onGateShellReady: (() -> Void)?
    var onGateLoadFailed: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(
            blockGateEnabled: blockGateEnabled,
            onBlockedIfGate: onBlockedIfGate,
            onGateShellReady: onGateShellReady,
            onGateLoadFailed: onGateLoadFailed
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.hasLoadedInitialRequest { return }
        context.coordinator.hasLoadedInitialRequest = true
        webView.load(URLRequest(url: startURL))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let blockGateEnabled: Bool
        private let onBlockedIfGate: (() -> Void)?
        private let onGateShellReady: (() -> Void)?
        private let onGateLoadFailed: (() -> Void)?
        fileprivate var hasLoadedInitialRequest = false
        fileprivate weak var webView: WKWebView?
        private var gateReadySignaled = false

        init(
            blockGateEnabled: Bool,
            onBlockedIfGate: (() -> Void)?,
            onGateShellReady: (() -> Void)?,
            onGateLoadFailed: (() -> Void)?
        ) {
            self.blockGateEnabled = blockGateEnabled
            self.onBlockedIfGate = onBlockedIfGate
            self.onGateShellReady = onGateShellReady
            self.onGateLoadFailed = onGateLoadFailed
        }

        private func evaluateGate(for url: URL?) -> Bool {
            guard blockGateEnabled else { return false }
            return LaunchGateConfiguration.urlContainsBlockedMarker(url)
        }

        private func notifyBlocked() {
            DispatchQueue.main.async {
                self.onBlockedIfGate?()
            }
        }

        private func notifyReadyIfGate() {
            guard blockGateEnabled else { return }
            guard !gateReadySignaled else { return }
            gateReadySignaled = true
            DispatchQueue.main.async {
                self.onGateShellReady?()
            }
        }

        private func notifyFailed() {
            DispatchQueue.main.async {
                self.onGateLoadFailed?()
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if evaluateGate(for: navigationAction.request.url) {
                decisionHandler(.cancel)
                notifyBlocked()
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if evaluateGate(for: navigationResponse.response.url) {
                decisionHandler(.cancel)
                notifyBlocked()
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            if evaluateGate(for: webView.url) {
                webView.stopLoading()
                notifyBlocked()
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            if evaluateGate(for: webView.url) {
                webView.stopLoading()
                notifyBlocked()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if evaluateGate(for: webView.url) {
                notifyBlocked()
                return
            }
            notifyReadyIfGate()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if blockGateEnabled {
                notifyFailed()
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if blockGateEnabled {
                notifyFailed()
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            if blockGateEnabled {
                notifyFailed()
            }
        }
    }
}

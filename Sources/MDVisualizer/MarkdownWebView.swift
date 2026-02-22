import AppKit
import SwiftUI
@preconcurrency import WebKit

enum NavigationDecision: Equatable {
    case allow
    case cancelOnly
    case cancelAndOpenExternally
}

@MainActor
struct MarkdownWebView: NSViewRepresentable {
    let markdownText: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        guard
            let htmlURL = Bundle.module.url(forResource: "index", withExtension: "html"),
            let resourceDir = Bundle.module.resourceURL
        else {
            return webView
        }

        webView.loadFileURL(htmlURL, allowingReadAccessTo: resourceDir)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard !markdownText.isEmpty else { return }

        let data = markdownText.data(using: .utf8) ?? Data()
        let base64 = data.base64EncodedString()

        if webView.isLoading {
            context.coordinator.pendingBase64 = base64
        } else {
            webView.evaluateJavaScript("window.renderMarkdown('\(base64)');", completionHandler: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate {
        var pendingBase64: String?
        weak var webView: WKWebView?
        var openURL: (URL) -> Void = { NSWorkspace.shared.open($0) }

        nonisolated static func policy(for url: URL,
                                       navigationType: WKNavigationType,
                                       bundleResourceURL: URL?) -> NavigationDecision {
            // 1. Allow file:// URLs within the app bundle resource directory
            if url.isFileURL {
                if let base = bundleResourceURL, url.path.hasPrefix(base.path) {
                    return .allow
                }
                return .cancelOnly   // file:// outside bundle (path traversal attempt)
            }

            // 2. http/https link the user explicitly clicked → open in system browser
            if (url.scheme == "http" || url.scheme == "https"),
               navigationType == .linkActivated {
                return .cancelAndOpenExternally
            }

            // 3. Everything else (JS redirects, meta-refresh, javascript: URIs, etc.) → cancel
            return .cancelOnly
        }

        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            switch Self.policy(for: url,
                               navigationType: navigationAction.navigationType,
                               bundleResourceURL: Bundle.module.resourceURL) {
            case .allow:
                decisionHandler(.allow)
            case .cancelOnly:
                decisionHandler(.cancel)
            case .cancelAndOpenExternally:
                openURL(url)
                decisionHandler(.cancel)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let base64 = pendingBase64 {
                pendingBase64 = nil
                webView.evaluateJavaScript("window.renderMarkdown('\(base64)');", completionHandler: nil)
            }
        }
    }
}

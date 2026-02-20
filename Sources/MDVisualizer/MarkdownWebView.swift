import SwiftUI
import WebKit

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

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let base64 = pendingBase64 {
                pendingBase64 = nil
                webView.evaluateJavaScript("window.renderMarkdown('\(base64)');", completionHandler: nil)
            }
        }
    }
}

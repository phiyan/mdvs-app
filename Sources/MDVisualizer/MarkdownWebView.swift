import AppKit
import SwiftUI
@preconcurrency import WebKit

// MARK: - DroppableWebView

/// WKWebView subclass that handles file-URL drag-and-drop at the AppKit level.
/// SwiftUI's .onDrop never fires when WKWebView fills the window, because AppKit
/// routes drag events to the front-most NSView first. This subclass registers for
/// public.file-url drags and intercepts them before WebKit can swallow them.
final class DroppableWebView: WKWebView {

    var onFileDrop: ((URL) -> Void)?
    var onDragChanged: ((Bool) -> Void)?

    convenience init() {
        self.init(frame: .zero, configuration: WKWebViewConfiguration())
    }

    override init(frame: NSRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    // MARK: - Pure static helpers (testable without a window or drag session)

    /// Returns `.copy` when the pasteboard contains at least one `.md` file URL,
    /// `[]` otherwise.
    static func draggingOperation(for pasteboard: NSPasteboard) -> NSDragOperation {
        fileURL(from: pasteboard) != nil ? .copy : []
    }

    /// Reads the first `.md` file URL from the pasteboard, or `nil` if none.
    static func fileURL(from pasteboard: NSPasteboard) -> URL? {
        let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
        return urls?.first { $0.pathExtension.lowercased() == "md" }
    }

    // MARK: - NSDraggingDestination overrides

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let op = Self.draggingOperation(for: sender.draggingPasteboard)
        if op != [] { onDragChanged?(true) }
        return op
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        Self.draggingOperation(for: sender.draggingPasteboard)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragChanged?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = Self.fileURL(from: sender.draggingPasteboard) else { return false }
        onFileDrop?(url)
        return true
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        onDragChanged?(false)
    }
}

// MARK: - NavigationDecision

enum NavigationDecision: Equatable {
    case allow
    case cancelOnly
    case cancelAndOpenExternally
}

// MARK: - MarkdownWebView

@MainActor
struct MarkdownWebView: NSViewRepresentable {
    let markdownText: String
    var onFileDrop: (URL) -> Void = { _ in }
    var onDragChanged: (Bool) -> Void = { _ in }

    func makeNSView(context: Context) -> DroppableWebView {
        let webView = DroppableWebView()
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        webView.onFileDrop = onFileDrop
        webView.onDragChanged = onDragChanged
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

    func updateNSView(_ webView: DroppableWebView, context: Context) {
        webView.onFileDrop = onFileDrop
        webView.onDragChanged = onDragChanged

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

import XCTest
import WebKit
@testable import MDVisualizer

@MainActor
final class NavigationPolicyTests: XCTestCase {

    // MARK: - Bundle file URL cases

    func test_bundleFileURL_isAllowed() {
        let base = URL(fileURLWithPath: "/private/var/app/resources")
        let url  = URL(fileURLWithPath: "/private/var/app/resources/index.html")
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .other, bundleResourceURL: base)
        XCTAssertEqual(result, .allow)
    }

    func test_fileURL_outsideBundle_isCancelled() {
        let base = URL(fileURLWithPath: "/private/var/app/resources")
        let url  = URL(fileURLWithPath: "/etc/passwd")
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .other, bundleResourceURL: base)
        XCTAssertEqual(result, .cancelOnly)
    }

    func test_fileURL_withNilBundleResourceURL_isCancelled() {
        let url = URL(fileURLWithPath: "/etc/passwd")
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .other, bundleResourceURL: nil)
        XCTAssertEqual(result, .cancelOnly)
    }

    func test_fragmentAnchorURL_isAllowed() {
        let base = URL(fileURLWithPath: "/private/var/app/resources")
        var comps = URLComponents(url: URL(fileURLWithPath: "/private/var/app/resources/index.html"),
                                  resolvingAgainstBaseURL: false)!
        comps.fragment = "section"
        let url = comps.url!
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .linkActivated, bundleResourceURL: base)
        XCTAssertEqual(result, .allow)
    }

    // MARK: - External link cases

    func test_httpsLinkActivated_opensExternally() {
        let url = URL(string: "https://example.com")!
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .linkActivated, bundleResourceURL: nil)
        XCTAssertEqual(result, .cancelAndOpenExternally)
    }

    func test_httpLinkActivated_opensExternally() {
        let url = URL(string: "http://example.com")!
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .linkActivated, bundleResourceURL: nil)
        XCTAssertEqual(result, .cancelAndOpenExternally)
    }

    func test_httpsOtherNavigation_cancelledOnly() {
        let url = URL(string: "https://evil.com")!
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .other, bundleResourceURL: nil)
        XCTAssertEqual(result, .cancelOnly)
    }

    func test_httpsFormSubmit_cancelledOnly() {
        let url = URL(string: "https://example.com/form")!
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .formSubmitted, bundleResourceURL: nil)
        XCTAssertEqual(result, .cancelOnly)
    }

    // MARK: - Blocked scheme cases

    func test_javascriptScheme_cancelled() {
        let url = URL(string: "javascript:alert(1)")!
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .linkActivated, bundleResourceURL: nil)
        XCTAssertEqual(result, .cancelOnly)
    }

    func test_ftpScheme_cancelled() {
        let url = URL(string: "ftp://example.com")!
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .linkActivated, bundleResourceURL: nil)
        XCTAssertEqual(result, .cancelOnly)
    }

    func test_dataScheme_cancelled() {
        let url = URL(string: "data:text/html,<h1>test</h1>")!
        let result = MarkdownWebView.Coordinator.policy(for: url, navigationType: .other, bundleResourceURL: nil)
        XCTAssertEqual(result, .cancelOnly)
    }

    // MARK: - Coordinator openURL spy tests

    func test_delegateCallsOpenURL_forLinkActivated() {
        let coordinator = MarkdownWebView.Coordinator()
        var openedURL: URL?
        coordinator.openURL = { openedURL = $0 }

        let url = URL(string: "https://example.com")!
        let decision = MarkdownWebView.Coordinator.policy(for: url, navigationType: .linkActivated, bundleResourceURL: nil)
        XCTAssertEqual(decision, .cancelAndOpenExternally)
        if decision == .cancelAndOpenExternally {
            coordinator.openURL(url)
        }
        XCTAssertEqual(openedURL, url)
    }

    func test_delegateDoesNotCallOpenURL_forJSRedirect() {
        let coordinator = MarkdownWebView.Coordinator()
        var openedURL: URL?
        coordinator.openURL = { openedURL = $0 }

        let url = URL(string: "https://evil.com")!
        let decision = MarkdownWebView.Coordinator.policy(for: url, navigationType: .other, bundleResourceURL: nil)
        XCTAssertEqual(decision, .cancelOnly)
        if decision == .cancelAndOpenExternally {
            coordinator.openURL(url)
        }
        XCTAssertNil(openedURL)
    }

    func test_delegateAllows_initialFileLoad() {
        let base = URL(fileURLWithPath: "/private/var/app/resources")
        let url  = URL(fileURLWithPath: "/private/var/app/resources/index.html")
        let decision = MarkdownWebView.Coordinator.policy(for: url, navigationType: .other, bundleResourceURL: base)
        XCTAssertEqual(decision, .allow)
    }
}

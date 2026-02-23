import XCTest
import AppKit
@testable import MDVisualizer

// All tests are @MainActor because they exercise NSView subclasses and NSPasteboard,
// both of which require main-thread access.
@MainActor
final class DragDropTests: XCTestCase {

    // MARK: - Helpers

    private func makePasteboard() -> NSPasteboard {
        let pb = NSPasteboard(name: .init("com.mdvisualizer.test.\(UUID().uuidString)"))
        pb.clearContents()
        return pb
    }

    // MARK: - draggingOperation(for:) — drag accept / reject decision

    func test_draggingOperation_mdFile_returnsCopy() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/test.md") as NSURL])
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), .copy)
    }

    func test_draggingOperation_uppercaseMDExtension_returnsCopy() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/README.MD") as NSURL])
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), .copy)
    }

    func test_draggingOperation_txtFile_returnsNone() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/notes.txt") as NSURL])
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), [])
    }

    func test_draggingOperation_htmlFile_returnsNone() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/page.html") as NSURL])
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), [])
    }

    func test_draggingOperation_noExtension_returnsNone() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/Makefile") as NSURL])
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), [])
    }

    func test_draggingOperation_markdownExtension_returnsNone() {
        // .markdown is not .md — only exact "md" is accepted
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/doc.markdown") as NSURL])
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), [])
    }

    func test_draggingOperation_webURL_returnsNone() {
        let pb = makePasteboard()
        pb.writeObjects([URL(string: "https://example.com")! as NSURL])
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), [])
    }

    func test_draggingOperation_emptyPasteboard_returnsNone() {
        let pb = makePasteboard()
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), [])
    }

    func test_draggingOperation_mdFileAmongNonMd_returnsCopy() {
        let pb = makePasteboard()
        pb.writeObjects([
            URL(fileURLWithPath: "/tmp/notes.txt") as NSURL,
            URL(fileURLWithPath: "/tmp/README.md") as NSURL,
        ])
        XCTAssertEqual(DroppableWebView.draggingOperation(for: pb), .copy)
    }

    // MARK: - fileURL(from:) — URL extraction

    func test_fileURL_mdFile_returnsURL() {
        let pb = makePasteboard()
        let expected = URL(fileURLWithPath: "/tmp/test.md")
        pb.writeObjects([expected as NSURL])
        XCTAssertEqual(DroppableWebView.fileURL(from: pb), expected)
    }

    func test_fileURL_uppercaseMD_returnsURL() {
        let pb = makePasteboard()
        let expected = URL(fileURLWithPath: "/tmp/README.MD")
        pb.writeObjects([expected as NSURL])
        XCTAssertEqual(DroppableWebView.fileURL(from: pb), expected)
    }

    func test_fileURL_txtFile_returnsNil() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/notes.txt") as NSURL])
        XCTAssertNil(DroppableWebView.fileURL(from: pb))
    }

    func test_fileURL_emptyPasteboard_returnsNil() {
        let pb = makePasteboard()
        XCTAssertNil(DroppableWebView.fileURL(from: pb))
    }

    func test_fileURL_webURL_returnsNil() {
        let pb = makePasteboard()
        pb.writeObjects([URL(string: "https://example.com")! as NSURL])
        XCTAssertNil(DroppableWebView.fileURL(from: pb))
    }

    func test_fileURL_multipleMdFiles_returnsFirst() {
        let pb = makePasteboard()
        let first  = URL(fileURLWithPath: "/tmp/first.md")
        let second = URL(fileURLWithPath: "/tmp/second.md")
        pb.writeObjects([first as NSURL, second as NSURL])
        XCTAssertEqual(DroppableWebView.fileURL(from: pb), first)
    }

    func test_fileURL_mdAmongNonMd_returnsMd() {
        let pb = makePasteboard()
        let txt = URL(fileURLWithPath: "/tmp/notes.txt")
        let md  = URL(fileURLWithPath: "/tmp/README.md")
        pb.writeObjects([txt as NSURL, md as NSURL])
        XCTAssertEqual(DroppableWebView.fileURL(from: pb), md)
    }

    // MARK: - DroppableWebView callback integration

    func test_performDrop_mdFile_callsOnFileDrop_withCorrectURL() {
        let pb = makePasteboard()
        let expected = URL(fileURLWithPath: "/tmp/test.md")
        pb.writeObjects([expected as NSURL])

        let webView = DroppableWebView()
        var droppedURL: URL?
        webView.onFileDrop = { droppedURL = $0 }

        _ = webView.performDragOperation(MockDraggingInfo(pasteboard: pb))
        XCTAssertEqual(droppedURL, expected)
    }

    func test_performDrop_txtFile_doesNotCallOnFileDrop() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/notes.txt") as NSURL])

        let webView = DroppableWebView()
        var called = false
        webView.onFileDrop = { _ in called = true }

        _ = webView.performDragOperation(MockDraggingInfo(pasteboard: pb))
        XCTAssertFalse(called)
    }

    func test_performDrop_mdFile_returnsTrue() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/test.md") as NSURL])

        let webView = DroppableWebView()
        webView.onFileDrop = { _ in }

        XCTAssertTrue(webView.performDragOperation(MockDraggingInfo(pasteboard: pb)))
    }

    func test_performDrop_txtFile_returnsFalse() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/notes.txt") as NSURL])

        let webView = DroppableWebView()
        XCTAssertFalse(webView.performDragOperation(MockDraggingInfo(pasteboard: pb)))
    }

    func test_draggingEntered_mdFile_returnsCopy() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/test.md") as NSURL])

        let webView = DroppableWebView()
        XCTAssertEqual(webView.draggingEntered(MockDraggingInfo(pasteboard: pb)), .copy)
    }

    func test_draggingEntered_mdFile_firesOnDragChangedTrue() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/test.md") as NSURL])

        let webView = DroppableWebView()
        var dragActive: Bool?
        webView.onDragChanged = { dragActive = $0 }

        _ = webView.draggingEntered(MockDraggingInfo(pasteboard: pb))
        XCTAssertEqual(dragActive, true)
    }

    func test_draggingEntered_txtFile_doesNotFireOnDragChanged() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/notes.txt") as NSURL])

        let webView = DroppableWebView()
        var called = false
        webView.onDragChanged = { _ in called = true }

        _ = webView.draggingEntered(MockDraggingInfo(pasteboard: pb))
        XCTAssertFalse(called)
    }

    func test_draggingUpdated_mdFile_returnsCopy() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/test.md") as NSURL])

        let webView = DroppableWebView()
        XCTAssertEqual(webView.draggingUpdated(MockDraggingInfo(pasteboard: pb)), .copy)
    }

    func test_draggingUpdated_txtFile_returnsNone() {
        let pb = makePasteboard()
        pb.writeObjects([URL(fileURLWithPath: "/tmp/notes.txt") as NSURL])

        let webView = DroppableWebView()
        XCTAssertEqual(webView.draggingUpdated(MockDraggingInfo(pasteboard: pb)), [])
    }

    func test_draggingExited_firesOnDragChangedFalse() {
        let webView = DroppableWebView()
        var dragActive: Bool?
        webView.onDragChanged = { dragActive = $0 }

        webView.draggingExited(nil)
        XCTAssertEqual(dragActive, false)
    }

    func test_draggingEnded_firesOnDragChangedFalse() {
        let pb = makePasteboard()
        let webView = DroppableWebView()
        var dragActive: Bool?
        webView.onDragChanged = { dragActive = $0 }

        webView.draggingEnded(MockDraggingInfo(pasteboard: pb))
        XCTAssertEqual(dragActive, false)
    }

    // MARK: - File content loading

    func test_readMarkdownFile_returnsFileContents() throws {
        let content = "# Hello\n\nThis is a **test**."
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try content.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        XCTAssertEqual(ContentView.readMarkdownFile(at: tmpURL), content)
    }

    func test_readMarkdownFile_nonExistentFile_returnsNil() {
        let url = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).md")
        XCTAssertNil(ContentView.readMarkdownFile(at: url))
    }

    func test_readMarkdownFile_emptyFile_returnsEmptyString() throws {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try "".write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        XCTAssertEqual(ContentView.readMarkdownFile(at: tmpURL), "")
    }

    func test_readMarkdownFile_unicodeContent_roundTrips() throws {
        let content = "# 日本語テスト\n\n*Émojis* 🎉\n\n```swift\nlet x = 42\n```"
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("md")
        try content.write(to: tmpURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        XCTAssertEqual(ContentView.readMarkdownFile(at: tmpURL), content)
    }
}

// MARK: - MockDraggingInfo

final class MockDraggingInfo: NSObject, NSDraggingInfo {
    private let _pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard) {
        _pasteboard = pasteboard
        super.init()
    }

    var draggingPasteboard: NSPasteboard { _pasteboard }
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSequenceNumber: Int { 0 }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggingLocation: NSPoint { .zero }
    var draggingSource: Any? { nil }
    var numberOfValidItemsForDrop: Int = 0
    var animatesToDestination: Bool = false
    var draggingFormation: NSDraggingFormation = .default

    @available(macOS 10.11, *)
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }

    @available(macOS 10.11, *)
    func resetSpringLoading() {}

    @available(macOS, deprecated: 10.7)
    var draggedImageLocation: NSPoint { .zero }

    @available(macOS, deprecated: 10.7)
    var draggedImage: NSImage? { nil }

    @available(macOS, deprecated: 10.7)
    func slideDraggedImage(to screenPoint: NSPoint) {}

    func enumerateDraggingItems(
        options enumOpts: NSDraggingItemEnumerationOptions,
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any],
        using block: @escaping (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
}

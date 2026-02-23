import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var markdownText: String = ""
    @State private var showFileImporter = false
    @State private var windowTitle = "MDVisualizer"
    @State private var isDragTargeted = false

    var body: some View {
        MarkdownWebView(
            markdownText: markdownText,
            onFileDrop: { url in loadFile(url: url) },
            onDragChanged: { active in isDragTargeted = active }
        )
        .overlay(alignment: .topLeading) {
            if isDragTargeted {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.08))
                    .ignoresSafeArea()
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.init(filenameExtension: "md") ?? .text],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                loadFile(url: url)
            }
        }
        .navigationTitle(windowTitle)
        .onReceive(NotificationCenter.default.publisher(for: .openFileRequested)) { _ in
            showFileImporter = true
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private func loadFile(url: URL) {
        guard let text = Self.readMarkdownFile(at: url) else { return }
        markdownText = text
        windowTitle = url.deletingPathExtension().lastPathComponent
    }

    /// Reads a markdown file from disk. Returns `nil` if the file cannot be read.
    /// Exposed as `static` so it can be exercised directly in unit tests.
    static func readMarkdownFile(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
}

extension Notification.Name {
    static let openFileRequested = Notification.Name("openFileRequested")
}

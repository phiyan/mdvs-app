import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var markdownText: String = ""
    @State private var showFileImporter = false
    @State private var windowTitle = "MDVisualizer"
    @State private var isDragTargeted = false

    var body: some View {
        MarkdownWebView(markdownText: markdownText)
            .overlay(alignment: .topLeading) {
                if isDragTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.08))
                        .ignoresSafeArea()
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDragTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, url.pathExtension.lowercased() == "md" else { return }
                    DispatchQueue.main.async {
                        loadFile(url: url)
                    }
                }
                return true
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
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            markdownText = text
            windowTitle = url.deletingPathExtension().lastPathComponent
        }
    }
}

extension Notification.Name {
    static let openFileRequested = Notification.Name("openFileRequested")
}

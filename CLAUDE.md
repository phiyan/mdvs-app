# MDVisualizer

Native macOS markdown viewer. Swift + SwiftUI shell with a `WKWebView` rendering markdown via `marked.js` (bundled — no network needed at runtime).

## Project Structure

```
main-app/
├── Package.swift
├── plans/
│   ├── roadmap.md                  # Multi-milestone roadmap
│   └── milestone-1-viewer.md       # M1 detailed plan
└── Sources/MDVisualizer/
    ├── App.swift                   # @main entry, File > Open menu
    ├── ContentView.swift           # Drag-and-drop + fileImporter
    ├── MarkdownWebView.swift       # NSViewRepresentable wrapping WKWebView
    ├── Info.plist                  # Required: NSPrincipalClass = NSApplication
    └── Resources/
        ├── index.html              # HTML template with renderMarkdown(base64)
        ├── marked.min.js           # Bundled JS parser (GFM support)
        └── style.css               # GitHub-inspired CSS, dark mode support
```

## Build & Run

```bash
swift build          # verify compilation
xed .               # open in Xcode, then Cmd+R to run
```

Target: **My Mac** (arm64). Platform: macOS 13+. Swift tools version: 5.9.

After any change to `Info.plist` or `Package.swift`, do **Product → Clean Build Folder** (`Cmd+Shift+K`) before running, or Xcode may use stale build artifacts.

## Key Architecture Decisions

- **Markdown rendering**: `marked.js` inside `WKWebView` — full GFM, no Swift dependency
- **Resource loading**: `Bundle.module.url(forResource:)` + `loadFileURL(_:allowingReadAccessTo: Bundle.module.resourceURL)` — SPM's `.process("Resources")` flattens files into the bundle root (no subdirectory path needed)
- **Swift → JS data transfer**: markdown is base64-encoded before being passed to `evaluateJavaScript`. The JS side decodes it. This avoids all quote/backslash escaping issues
- **Info.plist is mandatory**: SPM executable targets don't get window server access without `NSPrincipalClass = NSApplication` and `CFBundlePackageType = APPL`. Without it, the process starts but no window appears
- **File open**: two paths — `.onDrop(of: [.fileURL])` for drag-and-drop, `.fileImporter` triggered by a `NotificationCenter` post from `App.swift`'s `File > Open` command

## Swift 6 Concurrency

- `MarkdownWebView` and its `Coordinator` are both `@MainActor`
- `WKNavigationDelegate` callbacks are called on the main thread so this is safe
- `updateNSView` queues render via `Coordinator.pendingBase64` if the page hasn't finished loading yet

## Common Pitfalls

- **Window never appears**: `Info.plist` missing or not picked up — clean build and check it has `NSPrincipalClass = NSApplication`
- **JS/CSS not loading**: `loadFileURL` base URL must be `Bundle.module.resourceURL`, not the HTML file's parent. SPM flattens resources so there's no `Resources/` subdirectory at runtime
- **`GenerativeModelsAvailability` log warning**: system-level noise from Apple Intelligence framework, not from this app — safe to ignore

## Roadmap

- **M1** ✅ Viewer: open + render `.md` files
- **M2** Styling: `highlight.js` for code blocks, theme switcher
- **M3** Editor: split-pane `NSTextView` + live preview with scroll sync

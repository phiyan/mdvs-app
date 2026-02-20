import AppKit

// Set activation policy before SwiftUI initialises so macOS grants
// window-server access and treats this process as a foreground GUI app.
NSApplication.shared.setActivationPolicy(.regular)
MDVisualizerApp.main()

import AppKit

/// Debug helper for the README and design reviews: an image of one of the app's own
/// windows, as macOS draws it (translucent sidebars and toolbars included), taken in a
/// window moved off every screen. macOS lets an app capture its own windows without the
/// screen recording permission.
@MainActor
enum WindowSnapshot {
    /// Shows `window` off screen, waits for SwiftUI to lay it out, then writes it to `url`.
    static func capture(_ window: NSWindow, to url: URL, after delay: TimeInterval = 2,
                        completion: @escaping () -> Void) {
        window.ignoresMouseEvents = true
        window.orderFront(nil)
        // Moved off every screen once shown (macOS keeps it drawn), so it never shows up.
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            write(window, to: url)
            completion()
        }
    }

    /// Writes what `window` shows right now (already shown off screen).
    static func write(_ window: NSWindow, to url: URL) {
        guard let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber),
                                                  [.boundsIgnoreFraming, .bestResolution]) else { return }
        try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
    }
}

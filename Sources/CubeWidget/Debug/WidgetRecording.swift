import AppKit
import Combine
import SwiftUI

/// Debug helper for the README: `CubeWidget --record-widget folder` plays the widget's demo
/// in a window moved off every screen and saves one PNG every `frameInterval`
/// (frame-0000.png, …). The demo works (the blue light runs around the card), then starts
/// waiting for an answer (orange). Turn the frames into a GIF with ffmpeg or gifsicle.
@MainActor
final class WidgetRecording {
    static let frameInterval: TimeInterval = 0.04
    /// When the active demo session starts waiting, then when the recording stops.
    static let waitingAt: TimeInterval = 2.6
    static let duration: TimeInterval = 4.4

    private let board = SessionBoard(demo: true)
    private let cube: CubeAnimator
    private let window: NSWindow
    private var observer: AnyCancellable?

    init() {
        cube = CubeAnimator(mood: board.cubeMood)
        let content = CardStackView(board: board, cube: cube, isCollapsed: false, onToggleCollapsed: {})
            .padding(Constants.Window.haloMargin)
            .environment(\.widgetScale, 1)
            .background(Color(hex: 0x1C1C1E))
        let hosting = NSHostingView(rootView: content)
        window = NSWindow(contentRect: NSRect(origin: .zero, size: hosting.fittingSize),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = hosting
        // The cube follows the demo's active session, like in the real widget.
        observer = board.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self.map { $0.cube.mood = $0.board.cubeMood } }
        }
    }

    func start(to folder: URL, completion: @escaping () -> Void) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        window.ignoresMouseEvents = true
        window.orderFront(nil)
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        // A short wait for SwiftUI to lay the window out, then one frame at a time.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            let start = Date()
            var index = 0
            var waiting = false
            Timer.scheduledTimer(withTimeInterval: Self.frameInterval, repeats: true) { timer in
                MainActor.assumeIsolated {
                    let elapsed = Date().timeIntervalSince(start)
                    if !waiting, elapsed >= Self.waitingAt {
                        waiting = true
                        self.board.debugSetActiveStatus(.waiting)
                    }
                    let name = String(format: "frame-%04d.png", index)
                    WindowSnapshot.write(self.window, to: folder.appendingPathComponent(name))
                    index += 1
                    if elapsed >= Self.duration {
                        timer.invalidate()
                        completion()
                    }
                }
            }
        }
    }
}

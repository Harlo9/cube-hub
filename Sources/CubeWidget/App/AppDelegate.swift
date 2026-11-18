import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var widget: WidgetWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        HookProgram.install()
        let widget = WidgetWindowController()
        widget.show()
        self.widget = widget
        // Get sounds and colored frames ready now, so nothing freezes the first animations.
        SoundPlayer.preload()
        Task { @MainActor in FrameLibrary.preload() }
    }

    /// Click on the Dock icon, or the app opened again (Finder, Launchpad, Spotlight) while it
    /// already runs: macOS asks the app to "reopen". Show the Cube Hub, like a normal app.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        widget?.openHub()
        return false
    }

    /// Quitting stops the Claude sessions running in the Hub: ask first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard widget?.hasRunningHubProjects == true else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Quitter Cube Hub ?"
        alert.informativeText = "Les sessions Claude ouvertes dans le Cube Hub vont s'arrêter. Tu pourras reprendre leurs conversations en rouvrant l'app."
        alert.addButton(withTitle: "Quitter")
        alert.addButton(withTitle: "Annuler")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

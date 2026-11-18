import AppKit
import SwiftUI

/// The window shown at the first launch, while Claude Code is not connected: what Cube Hub
/// does, and "Brancher Claude Code" (the hooks of ~/.claude/settings.json, shown before
/// being added). Also in the widget's Debug menu.
///
/// Like Réglages, the app is a regular app (Dock icon) while it is open.
@MainActor
final class WelcomeWindowController: NSObject, NSWindowDelegate {
    private static let shownKey = "welcomeShown"
    private var window: NSWindow?

    /// At launch: only the first time, and only if the hooks are not all there.
    func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.shownKey),
              ClaudeHooks.shared.state != .connected else { return }
        show()
    }

    func show() {
        UserDefaults.standard.set(true, forKey: Self.shownKey)
        ClaudeHooks.shared.refresh()
        NSApp.setActivationPolicy(.regular)
        let window = self.window ?? makeWindow()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Debug helper (`--snapshot-welcome out.png`): the window as a new user sees it
    /// (Claude Code not plugged in yet), in an invisible window. Nothing is written.
    func snapshot(to url: URL, completion: @escaping () -> Void) {
        ClaudeHooks.shared.showStateForSnapshot(.disconnected)
        WindowSnapshot.capture(makeWindow(), to: url, completion: completion)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "Bienvenue"
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)   // dark, like the Hub
        window.isReleasedWhenClosed = false
        window.delegate = self
        let content = NSHostingView(rootView: WelcomeView(hooks: .shared) { [weak window] in window?.close() })
        window.contentView = content
        // Sized to its content before centering (the window follows it afterwards).
        window.setContentSize(content.fittingSize)
        window.center()
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        AppWindows.becomeAccessoryIfNoWindow(besides: window)
    }
}

private struct WelcomeView: View {
    @ObservedObject var hooks: ClaudeHooks
    let onClose: () -> Void
    @State private var showsPreview = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: Constants.Welcome.iconSize, height: Constants.Welcome.iconSize)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bienvenue dans Cube Hub").font(.title2.bold())
                    Text("Le cube te montre ce que font tes sessions Claude Code : bleu quand Claude bosse, orange quand il attend ta réponse, vert quand c'est fini.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
            }
            buttons
        }
        .padding(24)
        .frame(width: Constants.Welcome.width)
    }

    @ViewBuilder
    private var content: some View {
        switch hooks.state {
        case .connected:
            Label("Claude Code est branché", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(Constants.Colors.completed)
            Text("Les sessions déjà ouvertes apparaissent à leur prochain message. Les nouvelles, tout de suite.")
                .foregroundStyle(.secondary)
            Text("Le cube vit en haut à droite de ton écran (\(Constants.Window.toggleHotKeyLabel) pour le montrer ou le cacher) et dans la barre des menus. Double-clic sur une carte pour ouvrir le Cube Hub.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let backup = hooks.lastBackup {
                Text("Copie de ton ancien fichier : \(backup.path(percentEncoded: false))")
                    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            }
        case .unreadable(let reason):
            Label("Ton fichier de réglages de Claude Code est illisible", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(Constants.Colors.waiting)
            Text("~/.claude/settings.json : \(reason). Cube Hub n'y touche pas. Corrige-le, ou ajoute les hooks à la main (voir le README), puis rouvre cette fenêtre.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        case .disconnected, .partial:
            Text("Brancher Claude Code").font(.headline)
            Text("Pour suivre tes sessions, Cube Hub ajoute des « hooks » à Claude Code : à chaque étape (message, outil, fin de réponse…), Claude Code lance un petit programme qui note l'état de la session sur ton Mac. Rien ne quitte ton Mac.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Ce qui change : des lignes ajoutées à ~/.claude/settings.json. Une copie du fichier est faite avant, et tes autres réglages et hooks restent tels quels.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !hooks.isClaudeCodeInstalled {
                Label("Claude Code n'a pas l'air installé sur ce Mac.", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(Constants.Colors.waiting)
                Link("Installer Claude Code", destination: Constants.Welcome.claudeCodeURL)
            }
            DisclosureGroup("Voir les lignes ajoutées", isExpanded: $showsPreview) {
                ScrollView {
                    Text(hooks.preview)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: Constants.Welcome.previewHeight)
            }
            if let error {
                Text(error).foregroundStyle(Constants.Colors.waiting)
            }
        }
    }

    private var buttons: some View {
        HStack {
            Spacer()
            switch hooks.state {
            case .connected:
                Button("C'est parti", action: onClose).keyboardShortcut(.defaultAction)
            case .unreadable:
                Button("Fermer", action: onClose).keyboardShortcut(.defaultAction)
            case .disconnected, .partial:
                Button("Plus tard", action: onClose)
                Button("Brancher Claude Code") {
                    do { try hooks.connect(); error = nil } catch { self.error = "Échec : \(error.localizedDescription)" }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

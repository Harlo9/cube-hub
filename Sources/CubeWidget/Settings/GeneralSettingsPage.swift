import SwiftUI

/// "Général": what shows on the screen, and starting with the Mac.
struct GeneralSettingsPage: View {
    @ObservedObject var widget: WidgetSettings
    /// Read from macOS (not an app setting): refreshed when the page shows and after a change.
    @State private var launchesAtLogin = LaunchAtLogin.isEnabled
    @ObservedObject private var hooks = ClaudeHooks.shared
    @State private var hooksError: String?

    var body: some View {
        Form {
            Section("À l'écran") {
                Toggle(isOn: $widget.isVisible) {
                    SettingLabel("Afficher le widget",
                                 "Les cartes de tes sessions, toujours au-dessus des autres fenêtres. Raccourci \(Constants.Window.toggleHotKeyLabel), depuis n'importe quelle app. Le mini cube reste dans la barre du haut.")
                }
            }
            Section("Claude Code") {
                LabeledContent {
                    switch hooks.state {
                    case .connected:
                        Button("Débrancher") { run(hooks.disconnect) }
                    case .disconnected, .partial:
                        Button("Brancher") { run(hooks.connect) }
                    case .unreadable:
                        EmptyView()
                    }
                } label: {
                    SettingLabel(hooksTitle, hooksDetail)
                }
                if let hooksError {
                    Text(hooksError).foregroundStyle(Constants.Colors.waiting)
                }
            }
            Section("Démarrage") {
                Toggle(isOn: Binding(get: { launchesAtLogin }, set: { isOn in
                    LaunchAtLogin.set(isOn)
                    launchesAtLogin = LaunchAtLogin.isEnabled
                })) {
                    SettingLabel("Lancer au démarrage du Mac",
                                 "Visible dans Réglages Système → Général → Ouverture. Si l'app change de place, recoche cette option.")
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchesAtLogin = LaunchAtLogin.isEnabled
            hooks.refresh()
        }
    }

    private var hooksTitle: String {
        switch hooks.state {
        case .connected: "Hooks Claude Code : branchés ✓"
        case .partial: "Hooks Claude Code : en partie"
        case .disconnected: "Hooks Claude Code : pas branchés"
        case .unreadable: "Hooks Claude Code : fichier illisible"
        }
    }

    private var hooksDetail: String {
        switch hooks.state {
        case .connected:
            "Claude Code prévient Cube Hub à chaque étape de tes sessions. Débrancher retire seulement ces hooks de ~/.claude/settings.json (copie du fichier faite avant)."
        case .partial:
            "Certains hooks manquent : le cube peut rater des étapes. Brancher ajoute ceux qui manquent, sans toucher aux autres."
        case .disconnected:
            "Sans eux, le cube ne voit pas tes sessions. Brancher les ajoute à ~/.claude/settings.json (copie du fichier faite avant, tes autres réglages restent tels quels)."
        case .unreadable(let reason):
            "~/.claude/settings.json : \(reason). Cube Hub n'y touche pas : corrige-le, ou ajoute les hooks à la main (voir le README)."
        }
    }

    private func run(_ change: () throws -> Void) {
        do { try change(); hooksError = nil } catch { hooksError = "Échec : \(error.localizedDescription)" }
    }
}

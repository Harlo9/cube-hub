import SwiftUI

/// The Hub's demo (widget's Debug menu → "Hub de démo"): fake projects with neutral names,
/// sorted into fake themes, for screenshots and videos. No terminal is started and nothing
/// is saved: the real projects, themes and order come back when the demo ends.
enum HubDemo {
    private static let freelance = UUID()
    private static let personal = UUID()
    private static let content = UUID()

    static let themes: [HubTheme] = [
        HubTheme(id: freelance, name: "Freelance", colorIndex: 0),
        HubTheme(id: personal, name: "Projet perso", colorIndex: 1),
        HubTheme(id: content, name: "Création de contenu", colorIndex: 2),
    ]

    /// One fake session: its theme, status, age (minutes), context size and task.
    private static let entries: [(name: String, theme: UUID?, status: SessionStatus, minutes: Double, tokens: Int, task: String?)] = [
        ("client-dashboard", freelance, .working, 42, 118_000, "Ajouter les filtres par date"),
        ("api-server", freelance, .waiting, 95, 132_000, "Migrer la base de données"),
        ("portfolio", personal, .done, 34, 210_000, "Ajouter la page projets avec les captures"),
        ("recipe-app", personal, .working, 12, 48_000, "Écrire les tests du panier"),
        ("newsletter", content, .done, 21, 26_000, "Rédiger le brouillon du mois"),
        ("notes", nil, .done, 5, 9_000, nil),
    ]

    static var sessions: [Session] {
        entries.map { entry in
            Session(id: "hub-demo-\(entry.name)", projectName: entry.name, status: entry.status,
                    startedAt: Date().addingTimeInterval(-entry.minutes * 60), contextTokens: entry.tokens,
                    currentTask: entry.task, folder: URL(fileURLWithPath: "/demo/\(entry.name)"))
        }
    }

    /// Order key (folder path) → theme.
    static var assignment: [String: UUID] {
        Dictionary(uniqueKeysWithValues: entries.compactMap { entry in
            entry.theme.map { ("/demo/\(entry.name)", $0) }
        })
    }

    /// The session shown first.
    static let selectedID = "hub-demo-client-dashboard"

    /// What the fake terminal shows for a session, like a Claude Code conversation.
    static func transcript(for session: Session) -> String {
        let task = session.currentTask ?? "Mettre de l'ordre dans le projet"
        var lines = [
            "> \(task)",
            "",
            "⏺ Je regarde d'abord comment le projet est organisé.",
            "",
            "⏺ Read(README.md)",
            "  ⎿  Read 64 lines",
            "",
            "⏺ Search(pattern: \"TODO\", path: \"src\")",
            "  ⎿  Found 3 files",
            "",
            "⏺ Update(src/app.ts)",
            "  ⎿  Updated src/app.ts with 18 additions and 4 removals",
            "",
        ]
        switch session.status {
        case .working:
            lines += ["⏺ Bash(npm test)", "  ⎿  Running…", "", "✻ Working… (esc to interrupt)"]
        case .waiting:
            lines += [
                "⏺ Bash(npm run migrate)",
                "",
                "  Bash command",
                "    npm run migrate",
                "    Apply the database migrations",
                "",
                "  Do you want to proceed?",
                "  ❯ 1. Yes",
                "    2. No",
            ]
        case .done:
            lines += [
                "⏺ C'est fait : \(task.prefix(1).lowercased() + task.dropFirst()).",
                "  Les tests passent. Tu peux vérifier le résultat dans le navigateur.",
            ]
        }
        return lines.joined(separator: "\n")
    }
}

/// The right side of the Hub during the demo: the usual header above a fake terminal.
struct HubDemoTerminal: View {
    let session: Session

    var body: some View {
        VStack(spacing: 0) {
            HubSessionHeader(name: session.projectName, session: session, fallbackLabel: "")
            ScrollView {
                Text(HubDemo.transcript(for: session))
                    .font(.system(size: Constants.Hub.fontSize, design: .monospaced))
                    .foregroundStyle(Constants.Colors.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Constants.Hub.terminalPadding + 6)
            }
        }
        .background(Constants.Colors.cardBackground)
    }
}

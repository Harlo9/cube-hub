import Foundation

/// The Claude Code hooks that run `cube-hook`, in ~/.claude/settings.json: how the app
/// knows what each session does. The welcome window and Réglages → Général add them
/// ("Brancher") or remove them ("Débrancher").
///
/// Every change first copies the file next to it (settings.json.cubehub-backup-<date>), and
/// only touches the hooks that run `cube-hook`: the other settings and hooks are kept.
@MainActor
final class ClaudeHooks: ObservableObject {
    static let shared = ClaudeHooks()

    enum State: Equatable {
        /// Every event runs `cube-hook`.
        case connected
        /// Some events only (an older version of the hooks, or a hand edit).
        case partial
        case disconnected
        /// The file exists but is not JSON the app understands: it is left alone.
        case unreadable(String)
    }

    @Published private(set) var state: State = .disconnected
    /// The copy made before the last change.
    @Published private(set) var lastBackup: URL?

    /// The events `cube-hook` listens to, with their matcher (nil: every one).
    nonisolated static let events: [(name: String, matcher: String?)] = [
        ("SessionStart", nil), ("UserPromptSubmit", nil), ("PreToolUse", nil), ("PostToolUse", nil),
        ("PostToolUseFailure", nil), ("PermissionRequest", nil),
        ("Notification", "permission_prompt|idle_prompt|elicitation_dialog"),
        ("Stop", nil), ("StopFailure", nil), ("TaskCreated", nil), ("TaskCompleted", nil), ("SessionEnd", nil),
    ]

    private init() { refresh() }

    /// ~/.claude/settings.json (the real file, if it is a link to another one).
    var settingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/settings.json").resolvingSymlinksInPath()
    }

    private var command: String { HookProgram.installedURL.path }

    /// Claude Code seems to be installed (its folder or its program exists).
    var isClaudeCodeInstalled: Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return ["\(home)/.claude", "\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
            .contains { FileManager.default.fileExists(atPath: $0) }
    }

    func refresh() {
        switch read() {
        case .success(let settings): state = Self.state(of: settings)
        case .failure(let error): state = .unreadable(error.localizedDescription)
        }
    }

    func connect() throws { try change { Self.adding(to: $0, command: command) } }
    func disconnect() throws { try change { Self.removing(from: $0) } }

    /// What "Brancher" adds to the file, as shown before doing it.
    var preview: String {
        let added = Self.adding(to: [:], command: command)
        guard let data = try? JSONSerialization.data(withJSONObject: added, options: Self.writingOptions) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: - The file

    private struct Unreadable: LocalizedError {
        let errorDescription: String?
    }

    private static let writingOptions: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

    /// The settings, or an empty set when the file does not exist yet.
    private func read() -> Result<[String: Any], Error> {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return .success([:]) }
        do {
            let data = try Data(contentsOf: settingsURL)
            if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return .success([:]) }
            guard let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw Unreadable(errorDescription: "ce n'est pas un objet JSON")
            }
            return .success(settings)
        } catch let error as Unreadable {
            return .failure(error)
        } catch {
            return .failure(Unreadable(errorDescription: "JSON illisible"))
        }
    }

    /// Backs the file up, then writes the changed settings in one step.
    private func change(_ transform: ([String: Any]) -> [String: Any]) throws {
        let settings = try read().get()
        let url = settingsURL
        let fileManager = FileManager.default
        // The new file keeps the access rights of the old one (only you, for example).
        let permissions = (try? fileManager.attributesOfItem(atPath: url.path))?[.posixPermissions]
        if fileManager.fileExists(atPath: url.path) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let stamp = formatter.string(from: Date())
            let backup = url.deletingLastPathComponent().appendingPathComponent("settings.json.cubehub-backup-\(stamp)")
            try? fileManager.removeItem(at: backup)
            try fileManager.copyItem(at: url, to: backup)
            lastBackup = backup
        } else {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        var data = try JSONSerialization.data(withJSONObject: transform(settings), options: Self.writingOptions)
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
        if let permissions { try? fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path) }
        refresh()
    }

    // MARK: - The hooks (pure, tested)

    /// A hook runs `cube-hook` if its command ends with its path (absolute or with $HOME).
    nonisolated static func isCubeHook(_ hook: [String: Any]) -> Bool {
        (hook["command"] as? String)?.hasSuffix("/.cube-widget/bin/cube-hook") == true
    }

    nonisolated static func state(of settings: [String: Any]) -> State {
        let hooks = settings["hooks"] as? [String: Any] ?? [:]
        let connected = events.filter { event in
            (hooks[event.name] as? [[String: Any]] ?? []).contains { group in
                (group["hooks"] as? [[String: Any]] ?? []).contains(where: isCubeHook)
            }
        }.count
        return connected == events.count ? .connected : connected == 0 ? .disconnected : .partial
    }

    /// Adds a `cube-hook` hook to every event that has none, after the hooks already there.
    nonisolated static func adding(to settings: [String: Any], command: String) -> [String: Any] {
        var settings = settings
        var hooks = settings["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var groups = hooks[event.name] as? [[String: Any]] ?? []
            let hasOne = groups.contains { ($0["hooks"] as? [[String: Any]] ?? []).contains(where: isCubeHook) }
            guard !hasOne else { continue }
            var group: [String: Any] = ["hooks": [["type": "command", "command": command]]]
            if let matcher = event.matcher { group["matcher"] = matcher }
            groups.append(group)
            hooks[event.name] = groups
        }
        settings["hooks"] = hooks
        return settings
    }

    /// Removes every hook that runs `cube-hook`, and the groups and events left empty.
    nonisolated static func removing(from settings: [String: Any]) -> [String: Any] {
        var settings = settings
        guard var hooks = settings["hooks"] as? [String: Any] else { return settings }
        for (name, value) in hooks {
            guard let groups = value as? [[String: Any]] else { continue }
            let kept: [[String: Any]] = groups.compactMap { group in
                guard let list = group["hooks"] as? [[String: Any]] else { return group }
                let others = list.filter { !isCubeHook($0) }
                if others.isEmpty { return nil }
                var group = group
                group["hooks"] = others
                return group
            }
            hooks[name] = kept.isEmpty ? nil : kept
        }
        settings["hooks"] = hooks.isEmpty ? nil : hooks
        return settings
    }
}

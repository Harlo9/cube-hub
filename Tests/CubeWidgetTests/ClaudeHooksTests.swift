@testable import CubeWidget
import XCTest

/// "Brancher" / "Débrancher" Claude Code: only the hooks that run `cube-hook` change in
/// ~/.claude/settings.json, everything else is kept.
final class ClaudeHooksTests: XCTestCase {
    private let command = "/Users/me/.cube-widget/bin/cube-hook"

    private func hooks(_ settings: [String: Any]) -> [String: Any] {
        settings["hooks"] as? [String: Any] ?? [:]
    }

    private func commands(_ settings: [String: Any], _ event: String) -> [String] {
        (hooks(settings)[event] as? [[String: Any]] ?? [])
            .flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
            .compactMap { $0["command"] as? String }
    }

    func testEmptyFileGetsEveryEvent() {
        let settings = ClaudeHooks.adding(to: [:], command: command)
        XCTAssertEqual(ClaudeHooks.state(of: settings), .connected)
        XCTAssertEqual(hooks(settings).count, ClaudeHooks.events.count)
        let notification = (hooks(settings)["Notification"] as? [[String: Any]])?.first
        XCTAssertEqual(notification?["matcher"] as? String, "permission_prompt|idle_prompt|elicitation_dialog")
    }

    func testOtherSettingsAndHooksAreKept() {
        let mine: [String: Any] = [
            "model": "opus",
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "say done"]]]]],
        ]
        let settings = ClaudeHooks.adding(to: mine, command: command)
        XCTAssertEqual(settings["model"] as? String, "opus")
        XCTAssertEqual(commands(settings, "Stop"), ["say done", command])
    }

    func testAddingTwiceAddsNothing() {
        let once = ClaudeHooks.adding(to: [:], command: command)
        let twice = ClaudeHooks.adding(to: once, command: command)
        XCTAssertEqual(commands(twice, "Stop"), [command])
    }

    /// Hooks written by hand with $HOME count as connected too (no duplicate).
    func testHomeVariableIsRecognized() {
        let byHand = ClaudeHooks.adding(to: [:], command: "$HOME/.cube-widget/bin/cube-hook")
        XCTAssertEqual(ClaudeHooks.state(of: byHand), .connected)
        XCTAssertEqual(commands(ClaudeHooks.adding(to: byHand, command: command), "Stop"),
                       ["$HOME/.cube-widget/bin/cube-hook"])
    }

    func testPartial() {
        let settings: [String: Any] = ["hooks": ["Stop": [["hooks": [["type": "command", "command": command]]]]]]
        XCTAssertEqual(ClaudeHooks.state(of: settings), .partial)
        XCTAssertEqual(ClaudeHooks.state(of: ClaudeHooks.adding(to: settings, command: command)), .connected)
    }

    func testRemovingKeepsTheOthers() {
        let mine: [String: Any] = [
            "theme": "dark",
            "hooks": ["Stop": [["hooks": [["type": "command", "command": "say done"]]]]],
        ]
        let removed = ClaudeHooks.removing(from: ClaudeHooks.adding(to: mine, command: command))
        XCTAssertEqual(ClaudeHooks.state(of: removed), .disconnected)
        XCTAssertEqual(removed["theme"] as? String, "dark")
        XCTAssertEqual(commands(removed, "Stop"), ["say done"])
        XCTAssertEqual(hooks(removed).count, 1)   // the events left empty are gone
    }

    func testRemovingEverythingLeavesNoHooksKey() {
        let removed = ClaudeHooks.removing(from: ClaudeHooks.adding(to: ["theme": "dark"], command: command))
        XCTAssertNil(removed["hooks"])
        XCTAssertEqual(removed["theme"] as? String, "dark")
    }
}

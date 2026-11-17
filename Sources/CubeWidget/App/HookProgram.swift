import Foundation
import SessionFile

/// `cube-hook`, the small program run by the Claude Code hooks, ships inside the app
/// (Contents/Helpers). At launch, the app copies it to ~/.cube-widget/bin, where the hooks
/// of ~/.claude/settings.json find it: that path stays the same wherever the app is, and a
/// new version of the app brings its own `cube-hook` along.
enum HookProgram {
    static var installedURL: URL {
        SessionFiles.baseDirectory.appendingPathComponent("bin/cube-hook")
    }

    private static var bundledURL: URL? {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/cube-hook")
    }

    /// Copies the app's `cube-hook` if it is missing or different. Written from its bytes
    /// (not copied as a file), so the "downloaded from the internet" mark of the app does
    /// not follow it: macOS would refuse to run it from a hook. Written next to it then
    /// renamed, so a hook running right now never sees a half-written program.
    static func install() {
        guard let source = bundledURL, let program = try? Data(contentsOf: source) else { return }
        let target = installedURL
        if (try? Data(contentsOf: target)) == program { return }
        let fileManager = FileManager.default
        let temporary = target.appendingPathExtension("new")
        do {
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try program.write(to: temporary)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: temporary.path)
            // rename(2) replaces the old program in one step, and works when there is none.
            guard rename(temporary.path, target.path) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        } catch {
            try? fileManager.removeItem(at: temporary)
            NSLog("Cube Hub: could not install cube-hook (\(error.localizedDescription))")
        }
    }
}

import Foundation

extension URL {
    /// The path with the home folder written "~" ("~/Projets/site"): shorter, and the
    /// user's name stays out of screenshots.
    var tildePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = self.path
        return path == home || path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
}

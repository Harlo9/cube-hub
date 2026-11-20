@testable import CubeWidget
import Foundation
import XCTest

/// Folders shown with "~" for the home folder (Réglages, Telegram pages).
final class TildePathTests: XCTestCase {
    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    func testFolderInHome() {
        XCTAssertEqual(URL(fileURLWithPath: home + "/Projets/site").tildePath, "~/Projets/site")
    }

    func testHomeItself() {
        XCTAssertEqual(URL(fileURLWithPath: home).tildePath, "~")
    }

    func testFolderOutsideHome() {
        XCTAssertEqual(URL(fileURLWithPath: "/tmp/site").tildePath, "/tmp/site")
    }

    /// A folder whose name only starts like the home folder is not inside it.
    func testSimilarPrefixIsNotHome() {
        let path = home + "-backup/site"
        XCTAssertEqual(URL(fileURLWithPath: path).tildePath, path)
    }
}

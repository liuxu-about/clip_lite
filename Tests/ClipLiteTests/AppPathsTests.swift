import Foundation
import XCTest
@testable import ClipLite

final class AppPathsTests: XCTestCase {
    func test_resolveRelativePath_PathTraversal_ThrowsOutsideRoot() throws {
        XCTAssertThrowsError(try AppPaths.resolveRelativePath("../../etc/passwd")) { error in
            guard case AppPathError.outsideRoot = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func test_resolveRelativePath_ValidPath_StaysInsideRoot() throws {
        let resolved = try AppPaths.resolveRelativePath("Images/originals/sample.png")
        let root = try AppPaths.clipLiteRootDirectory()
            .standardizedFileURL
            .resolvingSymlinksInPath()

        XCTAssertTrue(resolved.path.hasPrefix(root.path + "/"))
    }

    func test_makeRelativePath_PathOutsideRoot_ThrowsOutsideRoot() throws {
        let outside = URL(fileURLWithPath: "/tmp/clip-lite-outside-check")
        XCTAssertThrowsError(try AppPaths.makeRelativePath(from: outside)) { error in
            guard case AppPathError.outsideRoot = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }
}

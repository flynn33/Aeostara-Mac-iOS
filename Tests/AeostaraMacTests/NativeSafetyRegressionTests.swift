import Foundation
import XCTest
import AeostaraMacDomain
import AeostaraMacServices

final class NativeSafetyRegressionTests: XCTestCase {
    func testLegacyContextFreeValidateFailsClosed() throws {
        let files = InMemoryFileSystem()
        files.files["/config.json"] = "{\"key\":\"value\"}"
        files.files["/desired.json"] = "{\"key\":\"value\"}"
        let runtime = buildTestEngine(fileSystem: files, semanticEnabled: false)
        XCTAssertThrowsError(try runtime.validate(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil))
    }
    func testLegacyContextFreeDiffCannotAuthorizeGenericRepair() throws {
        let files = InMemoryFileSystem()
        files.files["/config.json"] = "{\"key\":\"old\"}"
        files.files["/desired.json"] = "{\"key\":\"new\"}"
        let runtime = buildTestEngine(fileSystem: files, semanticEnabled: false)
        XCTAssertThrowsError(try runtime.diff(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil))
    }
    func testLegacyContextFreeHealCannotMutate() throws {
        let files = InMemoryFileSystem()
        files.files["/config.json"] = "{\"key\":\"old\"}"
        files.files["/desired.json"] = "{\"key\":\"new\"}"
        let original = files.files
        let runtime = buildTestEngine(fileSystem: files, semanticEnabled: false)
        XCTAssertThrowsError(try runtime.heal(configPath: "/config.json", desiredPath: "/desired.json", invariantsPath: nil, auditPath: "/audit.jsonl"))
        XCTAssertEqual(files.files, original)
    }
}

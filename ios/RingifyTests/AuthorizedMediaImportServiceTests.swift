import Foundation
import RingifyCore
import XCTest
@testable import Ringify

private actor StubMediaImportService: MediaImportService {
    func importMedia(from sourceURL: URL, kind: MediaSourceKind) async throws -> ImportedMedia {
        ImportedMedia(localURL: sourceURL, originalFilename: sourceURL.lastPathComponent, sourceKind: kind)
    }
}

@MainActor
final class AuthorizedMediaImportServiceTests: XCTestCase {
    func testRejectsSocialPlatformURLsEvenWhenHostIsListed() async {
        let service = RestrictedAuthorizedMediaImportService(
            importService: StubMediaImportService(),
            allowedHosts: ["youtube.com"]
        )

        do {
            _ = try await service.importAuthorizedMedia(from: URL(string: "https://youtube.com/watch?v=abc")!)
            XCTFail("Expected URL to be rejected")
        } catch {
            XCTAssertEqual(error as? RingifyError, .unauthorizedRemoteHost)
        }
    }

    func testRequiresExplicitHostAuthorization() async {
        let service = RestrictedAuthorizedMediaImportService(importService: StubMediaImportService())

        do {
            _ = try await service.importAuthorizedMedia(from: URL(string: "https://media.example.com/tone.m4a")!)
            XCTFail("Expected authorization to be required")
        } catch {
            XCTAssertEqual(error as? RingifyError, .authorizationRequired)
        }
    }
}

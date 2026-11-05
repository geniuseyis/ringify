import Foundation
import StoreKitTest
import XCTest

/// Real app navigation and unedited Simulator screenshots. No paid entitlement.
@MainActor final class NativeScreenshotsTests: XCTestCase {
    private let app = XCUIApplication()
    private var images: [[String: Any]] = []
    private let fixtureName = "Ringify Native Fixture"

    func testAllMainScreensInBothAppearances() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Ringify", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.storefront = "TUR"
        defer { app.terminate(); session.clearTransactions(); session.resetToDefaultState() }

        for theme in ["light", "dark"] {
            launch(theme: theme, holdSplash: true)
            try capture(1, "splash", theme: theme)

            launch(theme: theme, onboarding: true)
            waitFor("onboarding.continue")
            for page in 0..<3 {
                try capture(2, "onboarding-\(page + 1)", theme: theme)
                tap("onboarding.continue")
            }
            waitFor("home.create")
            try capture(3, "home-empty", theme: theme)
            tab("Stüdyo")
            XCTAssertFalse(app.buttons["studio.continue"].exists)
            try capture(6, "studio-empty", theme: theme)

            launch(theme: theme, fixture: true)
            tab("Stüdyo")
            waitFor("studio.continue", timeout: 45)
            tab("Ana Sayfa")
            try capture(3, "home-project", theme: theme)

            tap("home.create")
            waitFor("import.audio")
            try capture(4, "import", theme: theme)
            tap("import.microphone")
            waitFor("recorder.start")
            try capture(5, "recorder-idle", theme: theme)
            tap("recorder.back")
            returnToTabs()

            tab("Stüdyo")
            waitFor("studio.continue")
            try capture(6, "studio-project", theme: theme)
            tap("studio.playback")
            tap("studio.stop")
            tap("studio.continue")
            waitFor("effects.continue")
            try capture(7, "effects", theme: theme)
            tap("effects.continue")
            waitFor("preview.export", timeout: 45, enabled: true)
            try capture(8, "preview", theme: theme)
            tap("preview.export")
            waitFor("export.create")
            try capture(9, "export-form", theme: theme)
            tap("export.create")
            waitFor("export.share", timeout: 60)
            try capture(9, "export-success", theme: theme)
            tap("export.guide")
            waitFor("guide.method")
            try capture(10, "guide", theme: theme)
            tap("guide.help")
            waitFor("help.category")
            try capture(14, "help", theme: theme)
            returnToTabs()

            tab("Kütüphane")
            let project = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", fixtureName)).firstMatch
            XCTAssertTrue(project.waitForExistence(timeout: 15), "Actual imported project must remain in the library")
            try capture(11, "library", theme: theme)
            tab("Ayarlar")
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10))
            try capture(13, "settings", theme: theme)
            tab("Ana Sayfa")
            tap("home.pro")
            XCTAssertTrue(app.scrollViews.firstMatch.waitForExistence(timeout: 15))
            try capture(12, "pro", theme: theme)
            returnToTabs()
        }
        XCTAssertEqual(images.count, 38)
    }

    private func launch(theme: String, fixture: Bool = false, onboarding: Bool = false, holdSplash: Bool = false) {
        app.terminate()
        app.launchArguments = ["-RingifyUITesting", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment = ["RINGIFY_UI_TESTING": "1", "RINGIFY_UI_THEME": theme,
            "RINGIFY_UI_FIXTURE": fixture ? "1" : "0", "RINGIFY_UI_ONBOARDING": onboarding ? "1" : "0",
            "RINGIFY_UI_HOLD_SPLASH": holdSplash ? "1" : "0"]
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 20))
        if !onboarding && !holdSplash { waitFor("home.create") }
    }

    private func waitFor(_ identifier: String, timeout: TimeInterval = 20, enabled: Bool = false) {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), identifier)
        if enabled {
            let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: element)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, identifier)
        }
    }

    private func tap(_ identifier: String) {
        let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        _ = element.waitForExistence(timeout: 2)
        // LazyVGrid does not instantiate off-screen import cards. Scroll before
        // asserting existence, just as a person reveals the remaining sources.
        for _ in 0..<5 {
            if element.exists && element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists, identifier)
        XCTAssertTrue(element.isHittable, identifier)
        element.tap()
    }

    private func tab(_ label: String) {
        let element = app.tabBars.buttons[label]
        XCTAssertTrue(element.waitForExistence(timeout: 15), label)
        element.tap()
    }

    private func returnToTabs() {
        for _ in 0..<10 {
            if app.tabBars.firstMatch.exists && app.tabBars.firstMatch.isHittable { return }
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 5))
            back.tap()
        }
        XCTFail("Navigation did not return to the main tabs")
    }

    private func capture(_ number: Int, _ state: String, theme: String) throws {
        // The first SwiftUI accessibility window can report the content's intrinsic
        // height during launch. Measure the actual full-screen PNG instead.
        let screenshot = XCUIScreen.main.screenshot(), data = screenshot.pngRepresentation
        XCTAssertGreaterThanOrEqual(data.count, 24)
        let pixelWidth = data[16..<20].reduce(0) { ($0 << 8) | Int($1) }
        let pixelHeight = data[20..<24].reduce(0) { ($0 << 8) | Int($1) }
        let viewport = try XCTUnwrap([(390, 844), (393, 852)].first { width, height in
            (1...3).contains { scale in pixelWidth == width * scale && pixelHeight == height * scale }
        }, "Unexpected full-screen PNG dimensions \(pixelWidth)x\(pixelHeight)")
        let (width, height) = viewport
        let filename = "\(width)x\(height)-\(theme)-\(String(format: "%02d", number))-\(state).png"
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RingifyUIScreenshots", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: folder.appendingPathComponent(filename), options: .atomic)
        images.append(["number": number, "state": state, "theme": theme, "file": filename,
            "logicalWidth": width, "logicalHeight": height, "pixelWidth": pixelWidth, "pixelHeight": pixelHeight])
        let manifest: [String: Any] = ["source": "Unedited XCUIScreenshot from the running native app",
            "fixture": "Real generated PCM imported through production services; isolated memory store and preferences; no paid entitlement; recorder idle",
            "screenshots": images]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("manifest.json"), options: .atomic)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

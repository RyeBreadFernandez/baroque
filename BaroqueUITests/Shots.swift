import XCTest

// Saves full-device screenshots as PNGs into the repo's screenshots/ folder (the simulator can write host paths),
// and attaches them to the test result as well.
// Override the folder with TERRA_SCREENSHOT_DIR (pass TEST_RUNNER_TERRA_SCREENSHOT_DIR=... to xcodebuild).
enum Shots {
    static var directory: URL {
        if let dir = ProcessInfo.processInfo.environment["TERRA_SCREENSHOT_DIR"], !dir.isEmpty {
            return URL(fileURLWithPath: dir, isDirectory: true)
        }
        // BaroqueUITests/Shots.swift -> repo root -> screenshots/
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("screenshots", isDirectory: true)
    }

    @discardableResult
    static func save(_ name: String, in testCase: XCTestCase) -> Data {
        let shot = XCUIScreen.main.screenshot()
        let data = shot.pngRepresentation
        let dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(name.hasSuffix(".png") ? name : name + ".png")
        do {
            try data.write(to: url)
            print("TERRA-SHOT \(url.path)")
        } catch {
            print("TERRA-SHOT-FAILED \(url.path): \(error)")
        }
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
        return data
    }
}

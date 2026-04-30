import XCTest

final class WorkoutUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Screenshots

    func testCaptureHomeScreen() throws {
        let startBtn = app.buttons["Start Workout"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 5))
        screenshot("01_home")
    }

    func testCaptureHistoryScreen() throws {
        app.tabBars.buttons["History"].tap()
        Thread.sleep(forTimeInterval: 1)
        screenshot("02_history")
    }

    func testCaptureProgressScreen() throws {
        app.tabBars.buttons["Progress"].tap()
        Thread.sleep(forTimeInterval: 1)
        screenshot("03_progress")
    }

    func testCaptureSettingsScreen() throws {
        app.tabBars.buttons["Settings"].tap()
        Thread.sleep(forTimeInterval: 1)
        screenshot("04_settings")
    }

    func testCaptureActiveWorkout() throws {
        // Tap Start Workout
        let startBtn = app.buttons["Start Workout"]
        XCTAssertTrue(startBtn.waitForExistence(timeout: 5))
        startBtn.tap()
        Thread.sleep(forTimeInterval: 1.5)
        screenshot("05_active_workout_start")

        // Log all buttons so we know what identifiers are available
        let allBtns = app.buttons.allElementsBoundByIndex
        var btnLog = ""
        for btn in allBtns {
            btnLog += "id='\(btn.identifier)' label='\(btn.label)'\n"
        }
        let logAttachment = XCTAttachment(string: btnLog)
        logAttachment.name = "button_ids"
        logAttachment.lifetime = .keepAlways
        add(logAttachment)
        try? btnLog.write(toFile: "/tmp/uit_buttons.txt", atomically: true, encoding: .utf8)

        // Complete first set — try by SF symbol identifier then by label
        let checkmark = app.buttons.matching(identifier: "checkmark.circle").firstMatch
        let checkmarkFilled = app.buttons.matching(identifier: "checkmark.circle.fill").firstMatch
        if checkmark.exists {
            checkmark.tap()
        } else if checkmarkFilled.exists {
            checkmarkFilled.tap()
        }
        Thread.sleep(forTimeInterval: 1)
        screenshot("06_after_first_set")

        // Skip rest timer if visible
        let skipBtn = app.buttons["Skip"]
        if skipBtn.waitForExistence(timeout: 2) {
            skipBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
            screenshot("07_after_skip_rest")
        }

        // Fail a set — tap the X button
        let xBtn = app.buttons.matching(identifier: "xmark.circle").firstMatch
        if xBtn.exists {
            xBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
            screenshot("08_fail_set_rep_entry")
            let doneBtn = app.buttons["Done"]
            if doneBtn.waitForExistence(timeout: 2) { doneBtn.tap() }
        }

        // Scroll to see all exercises
        app.swipeUp()
        Thread.sleep(forTimeInterval: 0.5)
        screenshot("09_active_workout_scrolled")

        // Tap Finish → confirmation dialog
        app.buttons["Finish"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        screenshot("10_finish_dialog")

        // Confirm finish → summary screen
        app.buttons["Finish & Save"].tap()
        Thread.sleep(forTimeInterval: 1.5)
        screenshot("11_workout_summary")

        // Dismiss summary
        app.buttons["Done"].tap()
        Thread.sleep(forTimeInterval: 0.5)
        screenshot("12_home_after_finish")
    }

    // MARK: - Helpers

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let pngData = app.screenshot().pngRepresentation as Data? {
            let url = URL(fileURLWithPath: "/tmp/uit_\(name).png")
            try? pngData.write(to: url)
        }
    }
}

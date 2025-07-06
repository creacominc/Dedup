//
//  DedupUITestsLaunchTests.swift
//  DedupUITests
//
//  Created by Harold Tomlinson on 2025-07-05.
//

import XCTest

final class DedupUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Check that the main window appears
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        
        // Check that the app title and subtitle are visible
        XCTAssertTrue(app.staticTexts["Dedup"].exists)
        XCTAssertTrue(app.staticTexts["Media File Deduplication Tool"].exists)
        
        // Check that all expected tabs are present using accessibility identifiers
        let filesToMoveTab = app.buttons["tab-filesToMove"]
        let duplicatesTab = app.buttons["tab-duplicates"]
        let settingsTab = app.buttons["tab-settings"]
        XCTAssertTrue(filesToMoveTab.exists)
        XCTAssertTrue(duplicatesTab.exists)
        XCTAssertTrue(settingsTab.exists)
    }
} 
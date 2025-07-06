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

        // Insert assertions here to verify that the app launches successfully
        // and displays the expected UI elements
        
        // Check that the main window appears
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
        
        // Check that the app title is visible
        let titleText = app.staticTexts["Dedup"]
        XCTAssertTrue(titleText.exists)
        
        // Check that the subtitle is visible
        let subtitleText = app.staticTexts["Media File Deduplication Tool"]
        XCTAssertTrue(subtitleText.exists)
        
        // Verify the app is responsive by checking segmented control exists
        let segmentedControl = app.segmentedControls.firstMatch
        XCTAssertTrue(segmentedControl.exists)
        
        // Check that all expected tabs are present
        let filesToMoveTab = app.segmentedControls.buttons["Files to Move"]
        let duplicatesTab = app.segmentedControls.buttons["Duplicates"]
        let settingsTab = app.segmentedControls.buttons["Settings"]
        
        XCTAssertTrue(filesToMoveTab.exists)
        XCTAssertTrue(duplicatesTab.exists)
        XCTAssertTrue(settingsTab.exists)
    }
} 
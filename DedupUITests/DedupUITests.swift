//
//  DedupUITests.swift
//  DedupUITests
//
//  Created by Harold Tomlinson on 2025-07-05.
//

import XCTest

final class DedupUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAppLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Verify the app launches successfully
        XCTAssertTrue(app.windows.firstMatch.exists)
    }
    
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check that all expected tab buttons are present
        let filesToMoveTab = app.buttons["tabButton-filesToMove"]
        let duplicatesTab = app.buttons["tabButton-duplicates"]
        let settingsTab = app.buttons["tabButton-settings"]
        
        XCTAssertTrue(filesToMoveTab.exists)
        XCTAssertTrue(duplicatesTab.exists)
        XCTAssertTrue(settingsTab.exists)
        
        // Test switching between tabs
        duplicatesTab.tap()
        // Note: We can't easily verify tab selection state in UI tests
        // Just verify the tab exists and can be tapped
        
        settingsTab.tap()
        // Verify settings tab content is visible
        XCTAssertTrue(app.staticTexts["Directory Selection"].exists)
    }
    
    func testSettingsView() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to settings tab
        let settingsTab = app.buttons["tabButton-settings"]
        settingsTab.tap()
        
        // Check that settings elements are present
        XCTAssertTrue(app.staticTexts["Directory Selection"].exists)
        XCTAssertTrue(app.buttons["button-selectSource"].exists)
        XCTAssertTrue(app.buttons["button-selectTarget"].exists)
    }
    
    func testEmptyStateViews() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to files to move tab
        let filesToMoveTab = app.buttons["tabButton-filesToMove"]
        filesToMoveTab.tap()
        
        // Check that empty state is shown
        XCTAssertTrue(app.staticTexts["No files to move"].exists)
        XCTAssertTrue(app.staticTexts["Select source and target directories, then start processing to see files that can be moved."].exists)
        
        // Check that buttons are disabled when no files
        let selectAllButton = app.buttons["button-selectAllFiles"]
        let moveSelectedButton = app.buttons["button-moveSelectedFiles"]
        
        XCTAssertTrue(selectAllButton.exists)
        XCTAssertTrue(moveSelectedButton.exists)
        XCTAssertFalse(selectAllButton.isEnabled)
        XCTAssertFalse(moveSelectedButton.isEnabled)
    }
    
    func testErrorHandling() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to settings tab
        let settingsTab = app.buttons["tabButton-settings"]
        settingsTab.tap()
        
        // Check that error handling elements are present
        XCTAssertTrue(app.staticTexts["Directory Selection"].exists)
        XCTAssertTrue(app.staticTexts["Not selected"].exists)
    }
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
} 
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
        XCTAssertTrue(app.exists)
        
        // Check that the main window is visible
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists)
    }
    
    func testTabNavigation() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test tab navigation
        let filesToMoveTab = app.segmentedControls.buttons["Files to Move"]
        let duplicatesTab = app.segmentedControls.buttons["Duplicates"]
        let settingsTab = app.segmentedControls.buttons["Settings"]
        
        XCTAssertTrue(filesToMoveTab.exists)
        XCTAssertTrue(duplicatesTab.exists)
        XCTAssertTrue(settingsTab.exists)
        
        // Test switching between tabs
        duplicatesTab.tap()
        XCTAssertTrue(duplicatesTab.isSelected)
        
        settingsTab.tap()
        XCTAssertTrue(settingsTab.isSelected)
        
        filesToMoveTab.tap()
        XCTAssertTrue(filesToMoveTab.isSelected)
    }
    
    func testSettingsView() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to settings tab
        let settingsTab = app.segmentedControls.buttons["Settings"]
        settingsTab.tap()
        
        // Check that directory selection buttons exist
        let selectSourceButton = app.buttons["Select Source"]
        let selectTargetButton = app.buttons["Select Target"]
        let startProcessingButton = app.buttons["Start Processing"]
        
        XCTAssertTrue(selectSourceButton.exists)
        XCTAssertTrue(selectTargetButton.exists)
        XCTAssertTrue(startProcessingButton.exists)
        
        // Initially, start processing should be disabled
        XCTAssertFalse(startProcessingButton.isEnabled)
    }
    
    func testEmptyStateViews() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Check Files to Move tab empty state
        let filesToMoveTab = app.segmentedControls.buttons["Files to Move"]
        filesToMoveTab.tap()
        
        // Should show empty state message
        let noFilesText = app.staticTexts["No files to move"]
        XCTAssertTrue(noFilesText.exists)
        
        // Check Duplicates tab empty state
        let duplicatesTab = app.segmentedControls.buttons["Duplicates"]
        duplicatesTab.tap()
        
        let noDuplicatesText = app.staticTexts["No duplicates found"]
        XCTAssertTrue(noDuplicatesText.exists)
    }
    
    func testErrorHandling() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to settings and try to start processing without selecting directories
        let settingsTab = app.segmentedControls.buttons["Settings"]
        settingsTab.tap()
        
        let startProcessingButton = app.buttons["Start Processing"]
        
        // This should be disabled initially
        XCTAssertFalse(startProcessingButton.isEnabled)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
} 
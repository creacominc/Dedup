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
        
        // Use accessibility identifiers for tab navigation
        let filesToMoveTab = app.buttons["tab-filesToMove"]
        let duplicatesTab = app.buttons["tab-duplicates"]
        let settingsTab = app.buttons["tab-settings"]
        
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
        let settingsTab = app.buttons["tab-settings"]
        settingsTab.tap()
        
        // Verify settings view elements
        XCTAssertTrue(app.staticTexts["label-directorySelection"].exists)
        XCTAssertTrue(app.buttons["button-selectSource"].exists)
        XCTAssertTrue(app.buttons["button-selectTarget"].exists)
    }
    
    func testEmptyStateViews() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test Files to Move tab
        let filesToMoveTab = app.buttons["tab-filesToMove"]
        filesToMoveTab.tap()
        
        // Verify empty state
        XCTAssertTrue(app.staticTexts["label-noFilesToMove"].exists)
        
        // Test Duplicates tab
        let duplicatesTab = app.buttons["tab-duplicates"]
        duplicatesTab.tap()
        
        // Verify empty state
        XCTAssertTrue(app.staticTexts["label-noDuplicates"].exists)
    }
    
    func testErrorHandling() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to settings tab
        let settingsTab = app.buttons["tab-settings"]
        settingsTab.tap()
        
        // Try to start processing without selecting directories
        let startProcessingButton = app.buttons["button-startProcessing"]
        XCTAssertTrue(startProcessingButton.exists)
        XCTAssertFalse(startProcessingButton.isEnabled)
    }
    
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
} 
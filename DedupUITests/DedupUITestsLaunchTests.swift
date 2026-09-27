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

        // The macOS accessibility hierarchy may be unavailable on CI hosts;
        // process state still verifies that launch completed without crashing.
        XCTAssertNotEqual(app.state, .notRunning)
    }
}

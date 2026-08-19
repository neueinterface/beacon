//
//  SemeraUITests.swift
//  semera-iosUITests
//
//  Created by Armond Schneider on 3/7/26.
//

import XCTest

final class BeaconUITests: XCTestCase {

	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	@MainActor
	func testAppLaunches() throws {
		let app = XCUIApplication()
		app.launch()

		XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
	}

	@MainActor
	func testLaunchPerformance() throws {
		measure(metrics: [XCTApplicationLaunchMetric()]) {
			XCUIApplication().launch()
		}
	}
}

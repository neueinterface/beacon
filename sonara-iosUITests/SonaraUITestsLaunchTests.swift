//
//  SonaraUITestsLaunchTests.swift
//  sonara-iosUITests
//
//  Created by Armond Schneider on 3/7/26.
//

import XCTest

final class SonaraUITestsLaunchTests: XCTestCase {

	override class var runsForEachTargetApplicationUIConfiguration: Bool {
		true
	}

	override func setUpWithError() throws {
		continueAfterFailure = false
	}

	@MainActor
	func testLaunchScreenshot() throws {
		let app = XCUIApplication()
		app.launch()
		XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

		let attachment = XCTAttachment(screenshot: app.screenshot())
		attachment.name = "Launch Screen"
		attachment.lifetime = .keepAlways
		add(attachment)
	}
}

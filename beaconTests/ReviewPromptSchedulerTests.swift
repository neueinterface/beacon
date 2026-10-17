import Foundation
import Testing
@testable import beacon

@Suite("Occasional review invitations")
@MainActor
struct ReviewPromptSchedulerTests {
	private func withScheduler(_ test: (ReviewPromptScheduler, UserDefaults) -> Void) {
		let suite = "review-tests-\(UUID().uuidString)"
		let defaults = UserDefaults(suiteName: suite)!
		defer { defaults.removePersistentDomain(forName: suite) }
		test(ReviewPromptScheduler(defaults: defaults, chooseThreshold: { 3 }), defaults)
	}

	@Test("A few successful replies are required and the threshold persists")
	func usageAndPersistence() {
		withScheduler { scheduler, defaults in
			#expect(!scheduler.shouldOffer())
			scheduler.recordSuccessfulReply()
			scheduler.recordSuccessfulReply()
			#expect(!scheduler.shouldOffer())
			let reopened = ReviewPromptScheduler(defaults: defaults, chooseThreshold: { 6 })
			reopened.recordSuccessfulReply()
			#expect(reopened.shouldOffer())
		}
	}

	@Test("Deferring a busy screen does not consume an invitation")
	func deferredPresentation() {
		withScheduler { scheduler, _ in
			for _ in 0..<3 { scheduler.recordSuccessfulReply() }
			#expect(scheduler.shouldOffer())
			#expect(scheduler.shouldOffer())
			scheduler.recordPresentation()
			#expect(!scheduler.shouldOffer())
		}
	}

	@Test("Dismissed invitations have a 90-day cooldown and a yearly cap")
	func cooldownAndYearlyCap() {
		withScheduler { scheduler, _ in
			let start = Date(timeIntervalSince1970: 1_800_000_000)
			let day: TimeInterval = 24 * 60 * 60
			for offset in [0.0, 91.0, 182.0] {
				for _ in 0..<3 { scheduler.recordSuccessfulReply() }
				let now = start.addingTimeInterval(offset * day)
				#expect(scheduler.shouldOffer(now: now))
				scheduler.recordPresentation(now: now)
				for _ in 0..<3 { scheduler.recordSuccessfulReply() }
				#expect(!scheduler.shouldOffer(now: now.addingTimeInterval(day)))
			}
			#expect(!scheduler.shouldOffer(now: start.addingTimeInterval(273 * day)))
			#expect(scheduler.shouldOffer(now: start.addingTimeInterval(366 * day)))
		}
	}

	@Test("Choosing to rate stops automatic invitations across launches")
	func stopsAfterRatingIntent() {
		withScheduler { scheduler, defaults in
			for _ in 0..<6 { scheduler.recordSuccessfulReply() }
			scheduler.recordReviewPageOpened()
			let reopened = ReviewPromptScheduler(defaults: defaults, chooseThreshold: { 3 })
			#expect(!reopened.shouldOffer(now: Date.now.addingTimeInterval(500 * 24 * 60 * 60)))
		}
	}
}

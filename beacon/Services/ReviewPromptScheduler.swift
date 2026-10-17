import Foundation

/// Local-only counters for occasional review invitations, never chat content.
@MainActor
final class ReviewPromptScheduler {
	private enum Key {
		static let replies = "reviewInvitation.successfulReplies"
		static let threshold = "reviewInvitation.nextThreshold"
		static let dates = "reviewInvitation.presentationDates"
		static let choseToRate = "reviewInvitation.choseToRate"
	}

	private let defaults: UserDefaults
	private let chooseThreshold: () -> Int
	private let cooldown: TimeInterval = 90 * 24 * 60 * 60
	private let year: TimeInterval = 365 * 24 * 60 * 60

	init(defaults: UserDefaults = .standard, chooseThreshold: @escaping () -> Int = { Int.random(in: 3...6) }) {
		self.defaults = defaults
		self.chooseThreshold = chooseThreshold
	}

	private var threshold: Int {
		let stored = defaults.integer(forKey: Key.threshold)
		if (3...6).contains(stored) { return stored }
		let next = min(max(chooseThreshold(), 3), 6)
		defaults.set(next, forKey: Key.threshold)
		return next
	}

	func recordSuccessfulReply() {
		let count = defaults.integer(forKey: Key.replies)
		defaults.set(min(max(count, 0), threshold) + 1, forKey: Key.replies)
	}

	func shouldOffer(now: Date = .now) -> Bool {
		guard !defaults.bool(forKey: Key.choseToRate), defaults.integer(forKey: Key.replies) >= threshold else { return false }
		let dates = recentDates(now: now)
		guard dates.count < 3 else { return false }
		if let latest = dates.max(), now.timeIntervalSince(latest) < cooldown { return false }
		return true
	}

	/// Only consume eligibility once the invitation actually appears on screen.
	func recordPresentation(now: Date = .now) {
		guard shouldOffer(now: now) else { return }
		defaults.set(recentDates(now: now) + [now], forKey: Key.dates)
		defaults.set(0, forKey: Key.replies)
		defaults.set(min(max(chooseThreshold(), 3), 6), forKey: Key.threshold)
	}

	/// Opening the review page expresses intent, not proof a review was posted.
	/// Stop automatic invitations after that intent; Settings remains available.
	func recordReviewPageOpened() {
		defaults.set(true, forKey: Key.choseToRate)
	}

	private func recentDates(now: Date) -> [Date] {
		(defaults.array(forKey: Key.dates) as? [Date] ?? []).filter { now.timeIntervalSince($0) < year }
	}
}

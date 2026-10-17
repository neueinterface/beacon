import Foundation

/// Hub snapshots attach one child Progress per file. A parent's completed units
/// only count finished children; its fraction also includes bytes in flight.
struct ModelDownloadProgress {
	let fractionCompleted: Double
	let completedUnitCount: Int64?
	let totalUnitCount: Int64?

	init(_ progress: Progress) {
		let fraction = progress.fractionCompleted
		fractionCompleted = fraction.isFinite ? min(max(fraction, 0), 1) : 0
		let total = progress.totalUnitCount
		guard total > 0 else {
			completedUnitCount = nil
			totalUnitCount = nil
			return
		}
		totalUnitCount = total
		if fractionCompleted >= 1 {
			completedUnitCount = total
		} else {
			let bytes = min(Double(total) * fractionCompleted, Double(Int64.max).nextDown)
			completedUnitCount = Int64(bytes.rounded(.down))
		}
	}
}

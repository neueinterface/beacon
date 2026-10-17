import Foundation
import Testing
@testable import beacon

@Suite("Live model download progress")
@MainActor
struct ModelDownloadProgressTests {
	@Test("Partial file bytes count before a file finishes")
	func partialFileProgress() {
		let snapshot = Progress(totalUnitCount: 1_000)
		let weights = Progress(totalUnitCount: 800, parent: snapshot, pendingUnitCount: 800)
		let tokenizer = Progress(totalUnitCount: 200, parent: snapshot, pendingUnitCount: 200)
		weights.completedUnitCount = 400

		#expect(snapshot.completedUnitCount == 0)
		let partial = ModelDownloadProgress(snapshot)
		#expect(partial.completedUnitCount == 400)
		#expect(partial.totalUnitCount == 1_000)
		#expect(abs(partial.fractionCompleted - 0.4) < 0.000_001)

		weights.completedUnitCount = 800
		tokenizer.completedUnitCount = 100
		let nextFile = ModelDownloadProgress(snapshot)
		#expect(nextFile.completedUnitCount == 900)

		tokenizer.completedUnitCount = 200
		#expect(ModelDownloadProgress(snapshot).completedUnitCount == 1_000)
	}

	@Test("Direct byte progress remains exact and starts at zero")
	func directByteProgress() {
		let progress = Progress(totalUnitCount: 1_000)
		#expect(ModelDownloadProgress(progress).completedUnitCount == 0)
		#expect(ModelDownloadProgress(progress).fractionCompleted == 0)
		progress.completedUnitCount = 350
		#expect(ModelDownloadProgress(progress).completedUnitCount == 350)
	}

	@Test("Unknown totals do not fabricate downloaded bytes")
	func unknownTotal() {
		let snapshot = ModelDownloadProgress(Progress(totalUnitCount: 0))
		#expect(snapshot.totalUnitCount == nil)
		#expect(snapshot.completedUnitCount == nil)
		#expect(snapshot.fractionCompleted == 0)
	}

	@Test("Over-complete callbacks are clamped to the real total")
	func overCompleteProgress() {
		let progress = Progress(totalUnitCount: 100)
		progress.completedUnitCount = 150
		let snapshot = ModelDownloadProgress(progress)
		#expect(snapshot.completedUnitCount == 100)
		#expect(snapshot.fractionCompleted == 1)
	}
}

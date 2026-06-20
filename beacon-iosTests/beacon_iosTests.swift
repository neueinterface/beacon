//
//  beacon_iosTests.swift
//  beacon-iosTests
//
//  Created by Armond Schneider on 3/7/26.
//

import Testing
@testable import beacon_ios

@Suite("Beacon app data")
struct BeaconAppDataTests {
	@Test("Default model is available during onboarding")
	func defaultModelIsAvailableDuringOnboarding() {
		#expect(ModelCatalog.onboardingModels.contains(ModelCatalog.defaultModel))
	}

	@Test("Model lookup returns matching catalog model")
	func modelLookupReturnsMatchingModel() throws {
		let model = try #require(ModelCatalog.model(id: "beacon-lite"))

		#expect(model.id == "beacon-lite")
		#expect(model.repositoryID == "mlx-community/Qwen3-0.6B-4bit")
	}

	@Test("Built-in model formats size clearly")
	func builtInModelFormatsSizeClearly() throws {
		let model = try #require(ModelCatalog.model(id: "apple-foundation"))

		#expect(model.isBuiltIn)
		#expect(model.formattedSize == "Built in")
	}

	@Test("Downloadable models show GB size")
	func downloadableModelsShowGBSize() throws {
		let model = try #require(ModelCatalog.model(id: "beacon-plus"))

		#expect(!model.isBuiltIn)
		#expect(model.formattedSize.hasSuffix("GB"))
	}
}

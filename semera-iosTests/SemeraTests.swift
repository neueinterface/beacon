//
//  SemeraTests.swift
//  semera-iosTests
//
//  Created by Armond Schneider on 3/7/26.
//

import Testing
@testable import Semera

@Suite("Semera app data")
struct SemeraAppDataTests {
	@Test("Default model is available during onboarding")
	func defaultModelIsAvailableDuringOnboarding() {
		#expect(ModelCatalog.onboardingModels.contains(ModelCatalog.defaultModel))
	}

	@Test("Model lookup returns matching catalog model")
	func modelLookupReturnsMatchingModel() throws {
		let model = try #require(ModelCatalog.model(id: "semera-lite"))

		#expect(model.id == "semera-lite")
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
		let model = try #require(ModelCatalog.model(id: "semera-plus"))

		#expect(!model.isBuiltIn)
		#expect(model.formattedSize.hasSuffix("GB"))
	}
}

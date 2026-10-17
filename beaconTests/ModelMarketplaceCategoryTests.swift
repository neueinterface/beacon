import Testing
@testable import beacon

@Suite("Model marketplace tabs")
@MainActor
struct ModelMarketplaceCategoryTests {
	@Test("Chat Core and Recommended precede unique company tabs")
	func tabOrder() {
		let models = ModelCatalog.availableModels
		let options = ModelMarketplaceCategory.options(in: models)
		#expect(Array(options.prefix(2)) == [.chatCore, .recommended])
		#expect(options.count == Set(models.map(\.company)).count + 2)
		#expect(Set(options).count == options.count)
		#expect(Array(options.dropFirst(2)).map(\.title) == Set(models.map(\.company)).sorted())
	}

	@Test("Recommended models only includes good RAM fits")
	func recommendedModels() {
		let models = ModelCatalog.availableModels
		let recommended = ModelMarketplaceCategory.recommended.models(in: models) {
			ModelDeviceCompatibility.localModel($0, physicalMemoryGB: 6)
		}
		#expect(!recommended.isEmpty)
		#expect(recommended.allSatisfy { ModelDeviceCompatibility.localModel($0, physicalMemoryGB: 6) == .goodFit })
		#expect(!recommended.contains { $0.id == "qwen3-4b-instruct-2507" })
	}

	@Test("Company tabs preserve every model, including demanding options")
	func companiesKeepFullCatalog() {
		let models = ModelCatalog.availableModels
		let companies = Set(models.map(\.company))
		let browsable = companies.flatMap { company in
			ModelMarketplaceCategory.company(company).models(in: models, compatibility: { _ in .mayBeSlow })
		}
		#expect(Set(browsable.map(\.id)) == Set(models.map(\.id)))
		#expect(browsable.count == models.count)
		#expect(ModelMarketplaceCategory.company("Alibaba").models(in: models).allSatisfy { $0.company == "Alibaba" })
		#expect(Set(ModelMarketplaceCategory.company("Hugging Face").models(in: models).map(\.id)) == ["smollm3-3b", "smolvlm2-500m", "smollm-135m", "smollm-360m", "smollm-1.7b"])
	}

	@Test("Chat Core shows the same bundle as onboarding")
	func chatCoreBundle() {
		let models = ModelCatalog.availableModels
		let fits: (BeaconModel) -> ModelDeviceCompatibility = { _ in .goodFit }
		#expect(ModelMarketplaceCategory.chatCore.models(in: models, compatibility: fits).map(\.id)
			== ModelCatalog.coreOnboardingModels(in: models, compatibility: fits).map(\.id))
		#expect(ModelMarketplaceCategory.options(in: []) == [.chatCore, .recommended])
		#expect(ModelMarketplaceCategory.recommended.models(in: []).isEmpty)
	}
}

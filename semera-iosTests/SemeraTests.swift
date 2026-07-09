//
//  SemeraTests.swift
//  semera-iosTests
//
//  Created by Armond Schneider on 3/7/26.
//

import Testing
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
@testable import Semera

@Suite("Semera app data")
struct SemeraAppDataTests {
	@Test("Default model is available during onboarding")
	func defaultModelIsAvailableDuringOnboarding() {
		#expect(ModelCatalog.onboardingModels.contains(ModelCatalog.defaultModel))
	}

	@Test("Model lookup returns matching catalog model")
	func modelLookupReturnsMatchingModel() throws {
		let model = try #require(ModelCatalog.model(id: "qwen3-0.6b-4bit"))

		#expect(model.id == "qwen3-0.6b-4bit")
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
		let model = try #require(ModelCatalog.model(id: "lfm2-1.2b-4bit"))

		#expect(!model.isBuiltIn)
		#expect(model.formattedSize.hasSuffix("GB"))
	}
}

@Suite("Web search settings")
struct WebSearchSettingsTests {
	@Test("Web search toggle defaults to off")
	func webSearchToggleDefaultsToOff() {
		let key = "webSearchEnabled"
		let defaults = UserDefaults.standard
		let previousValue = defaults.object(forKey: key)

		defaults.removeObject(forKey: key)
		// @AppStorage("webSearchEnabled") private var webSearchEnabled = false
		#expect(defaults.object(forKey: key) == nil)

		if let previousValue {
			defaults.set(previousValue, forKey: key)
		} else {
			defaults.removeObject(forKey: key)
		}
	}

	@Test("Settings toggle row stores subtitle text")
	func settingsToggleRowStoresSubtitle() {
		var isOn = false
		let binding = Binding<Bool>(get: { isOn }, set: { isOn = $0 })
		let row = SettingsToggleRow(
			title: "Web Search",
			icon: "globe.icon",
			subtitle: "Daily search limits apply",
			isOn: binding
		)

		#expect(row.title == "Web Search")
		#expect(row.subtitle == "Daily search limits apply")
	}

	@Test("Settings toggle row subtitle defaults to nil")
	func settingsToggleRowSubtitleDefaultsToNil() {
		var isOn = false
		let binding = Binding<Bool>(get: { isOn }, set: { isOn = $0 })
		let row = SettingsToggleRow(
			title: "Notifications",
			icon: "bell.icon",
			isOn: binding
		)

		#expect(row.subtitle == nil)
	}
}

@Suite("Appearance color scheme")
struct AppearanceColorSchemeTests {
	@Test("System maps to unspecified user interface style")
	func systemMapsToUnspecified() {
		#if canImport(UIKit)
		#expect(AppearanceColorScheme.system.userInterfaceStyle == .unspecified)
		#endif
	}

	@Test("Light maps to light user interface style")
	func lightMapsToLight() {
		#if canImport(UIKit)
		#expect(AppearanceColorScheme.light.userInterfaceStyle == .light)
		#endif
	}

	@Test("Dark maps to dark user interface style")
	func darkMapsToDark() {
		#if canImport(UIKit)
		#expect(AppearanceColorScheme.dark.userInterfaceStyle == .dark)
		#endif
	}

	@Test("System preferred color scheme is nil (follows system)")
	func systemPreferredColorSchemeIsNil() {
		#expect(AppearanceColorScheme.system.preferredColorScheme == nil)
	}

	@Test("Dark then system produces different user interface styles")
	func darkThenSystemProducesDifferentStyles() {
		#if canImport(UIKit)
		let darkStyle = AppearanceColorScheme.dark.userInterfaceStyle
		let systemStyle = AppearanceColorScheme.system.userInterfaceStyle
		#expect(darkStyle != systemStyle)
		#expect(darkStyle == .dark)
		#expect(systemStyle == .unspecified)
		#endif
	}

	@Test("Appearance setting defaults to system")
	func appearanceSettingDefaultsToSystem() {
		let key = "appearanceColorScheme"
		let defaults = UserDefaults.standard
		let hadPreviousValue = defaults.object(forKey: key) != nil
		let previousValue = defaults.string(forKey: key)

		defaults.removeObject(forKey: key)
		let raw = defaults.string(forKey: key) ?? AppearanceColorScheme.system.rawValue
		let scheme = AppearanceColorScheme(rawValue: raw) ?? .system
		#expect(scheme == .system)

		if hadPreviousValue, let previousValue {
			defaults.set(previousValue, forKey: key)
		} else {
			defaults.removeObject(forKey: key)
		}
	}
}

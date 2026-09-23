import CoreText
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppTypography {
	private static let fontFiles = [
		"Neue-Regular",
		"Neue-Medium",
		"Neue-Bold",
		"Neue-Heavy",
		"Neue-Black"
	]

	static func registerFonts() {
		for fontFile in fontFiles {
			let fontURL = Bundle.main.url(forResource: fontFile, withExtension: "otf")
				?? Bundle.main.url(forResource: fontFile, withExtension: "otf", subdirectory: "Resources/Fonts")
			guard let fontURL else { continue }
			CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
		}

		#if canImport(UIKit)
		if let titleFont = UIFont(name: "Neue-Medium", size: 17),
		   let largeTitleFont = UIFont(name: "Neue-Bold", size: 34) {
			UINavigationBar.appearance().titleTextAttributes = [.font: titleFont]
			UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitleFont]
		}
		#endif
	}
}

extension Font {
	static func beaconFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
		let name: String
		if weight == .bold {
			name = "Neue-Bold"
		} else if weight == .semibold {
			name = "Neue-Bold"
		} else if weight == .medium {
			name = "Neue-Medium"
		} else {
			name = "Neue-Medium"
		}

		return .custom(name, size: size)
	}

	static func openRunde(size: CGFloat, weight: Font.Weight = .regular) -> Font {
		beaconFont(size: size, weight: weight)
	}
}

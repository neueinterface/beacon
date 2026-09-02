import CoreText
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppTypography {
	private static let fontFiles = [
		"OpenRunde-Regular",
		"OpenRunde-Medium",
		"OpenRunde-Semibold",
		"OpenRunde-Bold"
	]

	static func registerFonts() {
		for fontFile in fontFiles {
			let fontURL = Bundle.main.url(forResource: fontFile, withExtension: "otf")
				?? Bundle.main.url(forResource: fontFile, withExtension: "otf", subdirectory: "Resources/Fonts")
			guard let fontURL else { continue }
			CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
		}

		#if canImport(UIKit)
		if let titleFont = UIFont(name: "OpenRunde-Semibold", size: 17),
		   let largeTitleFont = UIFont(name: "OpenRunde-Bold", size: 34) {
			UINavigationBar.appearance().titleTextAttributes = [.font: titleFont]
			UINavigationBar.appearance().largeTitleTextAttributes = [.font: largeTitleFont]
		}
		#endif
	}
}

extension Font {
	static func openRunde(size: CGFloat, weight: Font.Weight = .regular) -> Font {
		let name: String
		if weight == .bold {
			name = "OpenRunde-Bold"
		} else if weight == .semibold {
			name = "OpenRunde-Semibold"
		} else if weight == .medium {
			name = "OpenRunde-Medium"
		} else {
			name = "OpenRunde-Regular"
		}

		return .custom(name, size: size)
	}
}

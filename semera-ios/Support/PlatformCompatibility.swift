#if os(macOS)
import AppKit
import SwiftUI

typealias UIColor = NSColor

extension Color {
	init(uiColor: NSColor) {
		self.init(nsColor: uiColor)
	}
}

extension NSColor {
	static var systemBackground: NSColor { .windowBackgroundColor }
	static var secondarySystemBackground: NSColor { .controlBackgroundColor }
	static var systemGroupedBackground: NSColor { .windowBackgroundColor }
	static var secondarySystemGroupedBackground: NSColor { .controlBackgroundColor }
	static var tertiarySystemGroupedBackground: NSColor { .underPageBackgroundColor }
	static var systemGray4: NSColor { .quaternaryLabelColor }
	static var systemGray5: NSColor { .controlBackgroundColor }
	static var systemGray6: NSColor { .separatorColor.withAlphaComponent(0.18) }
	static var separator: NSColor { .separatorColor }
	static var systemGreen: NSColor { NSColor(calibratedRed: 0.20, green: 0.78, blue: 0.35, alpha: 1) }
}
#endif

# Design

Beacon should feel calm, native, and focused. The visual system should stay minimal and rely on restraint rather than decoration.

## Core Colors

The primary palette is intentionally simple:

- Black
- White
- `systemGray6`
- Gray

Use these colors for the main interface, surfaces, text, controls, dividers, and quiet states.

## Alternative Colors

Alternative colors may be used for accents, labels, status indicators, categories, or model metadata.

When using an alternative color for text or foreground content, the background should use the same color at `10%` opacity.

Example:

```swift
Text("Creative")
    .foregroundStyle(.indigo)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(.indigo.opacity(0.10), in: Capsule())
```

If the text color is purple, the background should be purple at `0.10` opacity. If the text color is indigo, the background should be indigo at `0.10` opacity.

This keeps color usage soft, consistent, and readable without making the interface feel loud.

## Principle

Color should clarify, not compete.

Beacon should default to black, white, and gray. Use accent colors only when they add meaning or improve recognition.

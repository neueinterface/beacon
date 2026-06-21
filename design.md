# Design

Sonara should feel calm, native, and focused. The visual system should stay minimal and rely on restraint rather than decoration.

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

Sonara should default to black, white, and gray. Use accent colors only when they add meaning or improve recognition.

## Typography

Chat input and normal chat messages use `15pt` type.

Assistant Markdown should keep hierarchy, but the base body and code block size should remain `15pt`. Headings may be larger when they improve scanability.

## Thinking State

Thinking should feel like a live status, not a separate card.

- Use `15pt` secondary text
- Use the same shimmer treatment as the empty `Thinking...` placeholder while streaming
- Keep the chevron minimal
- Reveal details inline below the thinking label
- Do not expose raw model tags such as `<think>` in the final answer

## Sources

Sources should stay attached to the top of the assistant answer they support.

- The collapsed state reads `From N Sources`
- The source label stays anchored at the top
- The list reveals downward under the label
- The reveal should use a soft opacity/move transition with clipping and a subtle mask
- Source rows should be quiet: domain first, title second
- Tapping a source opens it in the in-app Safari view

## Web Search Disclosure

Web-backed answers should make their remote context visible without making the interface feel technical.

Search progress can appear in the thinking stream. Sources appear as a dropdown above the answer. The answer body should remain focused on the response, not on implementation details.

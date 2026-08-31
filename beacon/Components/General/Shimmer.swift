import SwiftUI

/// A view modifier that applies an animated shimmer effect.
public struct Shimmer: ViewModifier {
    public enum Mode {
        /// Masks the content with an animated gradient.
        case mask
        /// Overlays the gradient using a blend mode.
        case overlay(blendMode: BlendMode = .sourceAtop)
        /// Places the gradient behind the content.
        case background
    }

    private let animation: Animation
    private let gradient: Gradient
    private let min: CGFloat
    private let max: CGFloat
    private let mode: Mode

    @State private var isInitialState = true
    @Environment(\.layoutDirection) private var layoutDirection

    /// Creates a shimmer modifier with configurable animation and gradient.
    public init(
        animation: Animation = Self.defaultAnimation,
        gradient: Gradient = Self.defaultGradient,
        bandSize: CGFloat = 0.5,
        mode: Mode = .mask
    ) {
        self.animation = animation
        self.gradient = gradient
        self.min = 0 - bandSize
        self.max = 1 + bandSize
        self.mode = mode
    }

    /// Default one-way shimmer animation.
    public static let defaultAnimation = Animation.linear(duration: 1.5)
        .delay(0.25)
        .repeatForever(autoreverses: false)

    /// Default dark-band gradient used for masking.
    public static let defaultGradient = Gradient(colors: [
        .black.opacity(0.3),
        .black,
        .black.opacity(0.3)
    ])

    private var startPoint: UnitPoint {
        if layoutDirection == .rightToLeft {
            return isInitialState ? UnitPoint(x: max, y: min) : UnitPoint(x: 0, y: 1)
        } else {
            return isInitialState ? UnitPoint(x: min, y: min) : UnitPoint(x: 1, y: 1)
        }
    }

    private var endPoint: UnitPoint {
        if layoutDirection == .rightToLeft {
            return isInitialState ? UnitPoint(x: 1, y: 0) : UnitPoint(x: min, y: max)
        } else {
            return isInitialState ? UnitPoint(x: 0, y: 0) : UnitPoint(x: max, y: max)
        }
    }

    public func body(content: Content) -> some View {
        applyingGradient(to: content)
            .animation(animation, value: isInitialState)
            .onAppear {
                // Wait one run-loop so initial layout is established before animating.
                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    isInitialState = false
                }
            }
    }

    @ViewBuilder
    private func applyingGradient(to content: Content) -> some View {
        let linearGradient = LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint)

        switch mode {
        case .mask:
            content.mask(linearGradient)
        case let .overlay(blendMode: blendMode):
            content.overlay(linearGradient.blendMode(blendMode))
        case .background:
            content.background(linearGradient)
        }
    }
}

public extension View {
    /// Adds an animated shimmer effect to a view.
    @ViewBuilder
    func shimmering(
        active: Bool = true,
        animation: Animation = Shimmer.defaultAnimation,
        gradient: Gradient = Shimmer.defaultGradient,
        bandSize: CGFloat = 0.3,
        mode: Shimmer.Mode = .mask
    ) -> some View {
        if active {
            modifier(Shimmer(animation: animation, gradient: gradient, bandSize: bandSize, mode: mode))
        } else {
            self
        }
    }

    /// Deprecated convenience overload.
    @available(*, deprecated, message: "Use shimmering(active:animation:gradient:bandSize:mode:) instead.")
    @ViewBuilder
    func shimmering(
        active: Bool = true,
        duration: Double,
        bounce: Bool = false,
        delay: Double = 0.25
    ) -> some View {
        shimmering(
            active: active,
            animation: .linear(duration: duration).delay(delay).repeatForever(autoreverses: bounce)
        )
    }
}

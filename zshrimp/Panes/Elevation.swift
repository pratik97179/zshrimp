import AppKit
import QuartzCore

nonisolated enum Elevation {
    /// The pit sits 12pt in from the window's 26pt trailing corners (`ChassisView`), so its corners stay concentric with them.
    static let pitRadius: CGFloat = 14
    /// Seams fade to nothing this far from their ends.
    static let seamFade: CGFloat = 28
    /// Share of the split a seam covers, centered, so it never runs edge to edge.
    static let seamSpan: CGFloat = 0.6

    static func animation(keyPath: String, from: Float, to: Float, pace: Pace) -> CAAnimation {
        let animation: CABasicAnimation
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            animation = CABasicAnimation(keyPath: keyPath)
            animation.duration = 0.15
        } else if pace == .answer {
            let spring = CASpringAnimation(perceptualDuration: 0.32, bounce: 0)
            spring.keyPath = keyPath
            spring.duration = spring.settlingDuration
            animation = spring
        } else {
            animation = CABasicAnimation(keyPath: keyPath)
            animation.duration = pace == .settle ? 0.7 : 0.22
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.25, 0.1, 0.25, 1)
        }
        animation.fromValue = from
        animation.toValue = to
        return animation
    }

    /// Lighting up answers the user, so it is quick. Losing focus settles slowly, so the eye is never pulled back;
    /// a passing pointer lets go fast, so hover never lingers.
    enum Pace { case answer, settle, release }
}

/// How present a pane is. Only the focused pane is at full strength.
/// Every other pane fades toward its own background and loses most of its color; hover lifts that halfway.
nonisolated struct PaneLook: Equatable {
    let veil: Float
    let desaturation: Float

    static let rest = PaneLook(veil: 0.4, desaturation: 0.75)
    static let near = PaneLook(veil: 0.2, desaturation: 0.35)
    static let lit = PaneLook(veil: 0, desaturation: 0)
}

/// Pane colors taken from the current theme, so they suit dark, light and translucent setups alike.
struct ElevationPalette {
    let pit: NSColor
    let pitShade: NSColor
    let seam: NSColor
    let veil: NSColor
    let label: NSColor
    let running: NSColor
    let ink: NSColor
    let chassis: NSColor
    let chassisLit: NSColor
    let edge: NSColor

    init(_ values: Settings.Values) {
        let background = NSColor(hex: values.background) ?? .black
        let foreground = NSColor(hex: values.foreground) ?? .white
        let isLight = (background.usingColorSpace(.sRGB)?.brightnessComponent ?? 0) > 0.6
        // The pit is the terminal's own background, so panes have no edges of their own.
        pit = background.withAlphaComponent(values.opacity)
        // Shade falling in from the pit's rim, deepest under the top edge, so it reads as pressed into the chassis.
        pitShade = NSColor.black.withAlphaComponent(isLight ? 0.16 : 0.55)
        seam = foreground.withAlphaComponent(isLight ? 0.22 : 0.16)
        // Fading text toward its own background recedes it without tinting the surface.
        veil = background.withAlphaComponent(values.opacity)
        label = foreground.withAlphaComponent(0.55)
        ink = foreground.withAlphaComponent(0.9)
        // The chassis sits a step toward the foreground from the terminal, so the workspace reads as set into it.
        let body = background.blended(withFraction: isLight ? 0.04 : 0.07, of: foreground) ?? background
        chassis = body.withAlphaComponent(max(values.opacity, 0.85))
        chassisLit = (body.blended(withFraction: isLight ? 0.5 : 0.04, of: .white) ?? body).withAlphaComponent(max(values.opacity, 0.85))
        edge = NSColor.white.withAlphaComponent(isLight ? 0.6 : 0.09)
        // The theme's green, so the dot belongs to the palette the shell already uses.
        running = values.palette.count > 2 ? NSColor(hex: values.palette[2]) ?? .systemGreen : .systemGreen
    }
}

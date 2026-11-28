import AppKit
import QuartzCore

nonisolated enum Elevation {
    static let gap: CGFloat = 6
    // A titled window's corners are 16pt; a pane one gap in keeps its corners concentric with them.
    static let cornerRadius: CGFloat = 16 - gap

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

/// How present a pane is. Only the focused pane is at full strength: its rim catches the light.
/// Every other pane fades toward its own background and loses most of its color; hover lifts that halfway.
nonisolated struct PaneLook: Equatable {
    let rim: Float
    let veil: Float
    let desaturation: Float

    static let rest = PaneLook(rim: 0, veil: 0.4, desaturation: 0.75)
    static let near = PaneLook(rim: 0.3, veil: 0.2, desaturation: 0.35)
    static let lit = PaneLook(rim: 1, veil: 0, desaturation: 0)
}

/// Pane colors taken from the current theme, so they suit dark, light and translucent setups alike.
struct ElevationPalette {
    let workspace: NSColor
    let veil: NSColor
    let rim: NSColor
    let label: NSColor
    let running: NSColor

    init(_ values: Settings.Values) {
        let background = NSColor(hex: values.background) ?? .black
        let foreground = NSColor(hex: values.foreground) ?? .white
        let isLight = (background.usingColorSpace(.sRGB)?.brightnessComponent ?? 0) > 0.6
        // Panes sit lighter than the ground they rest on, so the gap reads as space, not a seam.
        workspace = (background.blended(withFraction: isLight ? 0.08 : 0.4, of: .black) ?? background).withAlphaComponent(values.opacity)
        // Fading text toward its own background recedes it without tinting the surface.
        veil = background.withAlphaComponent(values.opacity)
        rim = foreground.withAlphaComponent(isLight ? 0.5 : 0.55)
        label = foreground.withAlphaComponent(0.55)
        // The theme's green, so the dot belongs to the palette the shell already uses.
        running = values.palette.count > 2 ? NSColor(hex: values.palette[2]) ?? .systemGreen : .systemGreen
    }
}

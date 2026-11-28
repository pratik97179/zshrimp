import AppKit

/// The chrome's voice: SF Pro Rounded, soft like the rail's platforms. Terminal text keeps the monospaced face from Settings.
enum Typography {
    static func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }

    static let railName = rounded(15, .semibold)
    static let railNameKern: CGFloat = 2.5
    static let paneLabel = rounded(11, .medium)
}

import AppKit
import Observation

@Observable
final class Settings {
    struct Values: Codable, Equatable {
        /// Empty means the system monospaced font.
        var fontName = ""
        var fontSize = 13.0
        var foreground = "#D9D9D9"
        var background = "#000000"
        var palette = Theme.all[0].palette
        /// How much the background color covers what is behind it: the desktop or the background image.
        var opacity = 1.0
        var padding = 4.0
        /// Empty means no image.
        var backgroundImage = ""
        var isFloating = false
    }

    static let shared = Settings()
    private static let key = "settings"

    var values: Values {
        didSet { save() }
    }

    private init() {
        values = UserDefaults.standard.data(forKey: Self.key).flatMap(Self.decode) ?? Values()
    }

    // Saved keys override the defaults, so settings added later don't reset the ones already saved.
    private static func decode(_ data: Data) -> Values? {
        guard
            let defaults = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(Values())) as? [String: Any],
            let saved = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let merged = try? JSONSerialization.data(withJSONObject: defaults.merging(saved) { $1 })
        else { return nil }
        return try? JSONDecoder().decode(Values.self, from: merged)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(values) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

extension Settings.Values {
    var font: NSFont {
        NSFont(name: fontName, size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    /// The preset these colors came from; nil once any of them is edited by hand.
    var theme: Theme? {
        Theme.all.first { $0.foreground == foreground && $0.background == background && $0.palette == palette }
    }

    mutating func apply(_ theme: Theme) {
        foreground = theme.foreground
        background = theme.background
        palette = theme.palette
    }

    var backgroundColor: NSColor {
        (NSColor(hex: background) ?? .black).withAlphaComponent(opacity)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        guard hex.hasPrefix("#"), hex.count == 7, let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var hex: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        let component = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", component(rgb.redComponent), component(rgb.greenComponent), component(rgb.blueComponent))
    }
}

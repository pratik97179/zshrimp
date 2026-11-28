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
        var isFloating = false
    }

    static let shared = Settings()
    private static let key = "settings"

    var values: Values {
        didSet { save() }
    }

    private init() {
        let data = UserDefaults.standard.data(forKey: Self.key)
        values = data.flatMap { try? JSONDecoder().decode(Values.self, from: $0) } ?? Values()
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

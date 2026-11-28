import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable private var settings = Settings.shared

    private let fontNames = NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []

    var body: some View {
        Form {
            Section("Appearance") {
                ColorPicker("Text", selection: color(\.foreground), supportsOpacity: false)
                ColorPicker("Background", selection: color(\.background), supportsOpacity: false)
            }
            Section("Font") {
                Picker("Family", selection: $settings.values.fontName) {
                    Text("System Monospaced").tag("")
                    ForEach(fontNames, id: \.self) { name in
                        Text(NSFont(name: name, size: 13)?.displayName ?? name).tag(name)
                    }
                }
                Stepper(value: $settings.values.fontSize, in: 8...36, step: 1) {
                    Text("Size \(Int(settings.values.fontSize))")
                }
            }
            Section("Window") {
                Toggle("Float on top", isOn: $settings.values.isFloating)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func color(_ keyPath: WritableKeyPath<Settings.Values, String>) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: settings.values[keyPath: keyPath]) ?? .black) },
            set: { settings.values[keyPath: keyPath] = NSColor($0).hex }
        )
    }
}

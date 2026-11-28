import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Bindable private var settings = Settings.shared

    private let fontNames = NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: theme) {
                    ForEach(Theme.all) { Text($0.name).tag($0.name) }
                    if settings.values.theme == nil {
                        Text("Custom").tag("")
                    }
                }
                ColorPicker("Text", selection: color(\.foreground), supportsOpacity: false)
                ColorPicker("Background", selection: color(\.background), supportsOpacity: false)
                Slider(value: $settings.values.opacity, in: 0.2...1) {
                    Text("Opacity")
                }
                Stepper(value: $settings.values.padding, in: 0...40, step: 2) {
                    Text("Padding \(Int(settings.values.padding))")
                }
            }
            Section("Background") {
                LabeledContent("Image") {
                    HStack {
                        Text(imageName).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        Button("Choose…", action: chooseImage)
                        if !settings.values.backgroundImage.isEmpty {
                            Button("Clear") { settings.values.backgroundImage = "" }
                        }
                    }
                }
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

    private var imageName: String {
        let path = settings.values.backgroundImage
        return path.isEmpty ? "None" : (path as NSString).lastPathComponent
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.level = .floating
        if panel.runModal() == .OK, let url = panel.url {
            settings.values.backgroundImage = url.path
        }
    }

    private var theme: Binding<String> {
        Binding(
            get: { settings.values.theme?.name ?? "" },
            set: { name in
                if let theme = Theme.all.first(where: { $0.name == name }) { settings.values.apply(theme) }
            }
        )
    }

    private func color(_ keyPath: WritableKeyPath<Settings.Values, String>) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: NSColor(hex: settings.values[keyPath: keyPath]) ?? .black) },
            set: { settings.values[keyPath: keyPath] = NSColor($0).hex }
        )
    }
}

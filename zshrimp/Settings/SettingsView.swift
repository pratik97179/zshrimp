import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Settings as the main window draws itself: no cards, headings set to the left, rows parted by faded seams,
/// and controls on the same soft round platforms as the rail.
struct SettingsView: View {
    @Bindable private var settings = Settings.shared

    private let fontNames = NSFontManager.shared.availableFontNames(with: .fixedPitchFontMask) ?? []

    var body: some View {
        let palette = ElevationPalette(settings.values)
        VStack(alignment: .leading, spacing: 26) {
            section("appearance") {
                row("Theme") {
                    MenuField(title: settings.values.theme?.name ?? "Custom", items: Theme.all.map(\.name)) { name in
                        if let theme = Theme.all.first(where: { $0.name == name }) { settings.values.apply(theme) }
                    }
                }
                Seam()
                row("Text") { Swatch(hex: $settings.values.foreground) }
                Seam()
                row("Background") { Swatch(hex: $settings.values.background) }
                Seam()
                row("Opacity") {
                    HStack(spacing: 10) {
                        Slider(value: $settings.values.opacity, in: 0.2...1).labelsHidden().controlSize(.small).frame(width: 130)
                        Value(text: "\(Int((settings.values.opacity * 100).rounded()))%")
                    }
                }
                Seam()
                row("Padding") { Steps(value: $settings.values.padding, range: 0...40, step: 2) }
            }
            section("background") {
                row("Image") {
                    HStack(spacing: 14) {
                        Text(imageName).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Color(nsColor: palette.label)).lineLimit(1).truncationMode(.middle).frame(maxWidth: 120, alignment: .trailing)
                        TextAction(title: "choose", action: chooseImage)
                        if !settings.values.backgroundImage.isEmpty {
                            TextAction(title: "clear") { settings.values.backgroundImage = "" }
                        }
                    }
                }
            }
            section("font") {
                row("Family") {
                    MenuField(
                        title: settings.values.fontName.isEmpty ? "System Monospaced" : NSFont(name: settings.values.fontName, size: 13)?.displayName ?? settings.values.fontName,
                        items: [""] + fontNames,
                        label: { $0.isEmpty ? "System Monospaced" : NSFont(name: $0, size: 13)?.displayName ?? $0 }
                    ) { settings.values.fontName = $0 }
                }
                Seam()
                row("Size") { Steps(value: $settings.values.fontSize, range: 8...36, step: 1) }
            }
            section("window") {
                row("Float on top") {
                    Toggle("", isOn: $settings.values.isFloating).labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 24)
        .frame(width: 460)
        .background(Pit(palette: palette))
        .fontDesign(.rounded)
        .tint(Color(nsColor: palette.ink))
        .environment(\.palette, palette)
    }

    private func section(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Heading(text: title).frame(width: 104, alignment: .leading)
            VStack(spacing: 0) { rows() }
        }
    }

    private func row(_ title: String, @ViewBuilder control: () -> some View) -> some View {
        HStack {
            Label(text: title)
            Spacer(minLength: 16)
            control()
        }
        .frame(height: 38)
    }

    private var imageName: String {
        let path = settings.values.backgroundImage
        return path.isEmpty ? "none" : (path as NSString).lastPathComponent
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.level = .floating
        if panel.runModal() == .OK, let url = panel.url {
            settings.values.backgroundImage = url.path
        }
    }
}

// MARK: - Pieces

private extension EnvironmentValues {
    @Entry var palette = ElevationPalette(Settings.Values())
}

/// The sunken well the settings sit in, as the terminals do: the theme's own ground, shaded under its top edge.
private struct Pit: View {
    let palette: ElevationPalette

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Elevation.pitRadius, style: .continuous)
        shape.fill(Color(nsColor: palette.pit))
            .overlay(
                shape.fill(LinearGradient(colors: [Color(nsColor: palette.pitShade), .clear], startPoint: .top, endPoint: .init(x: 0.5, y: 0.08)))
            )
            .clipShape(shape)
    }
}

/// A 1pt seam that fades out toward both ends, like the dividers between panes.
private struct Seam: View {
    @Environment(\.palette) private var palette

    var body: some View {
        let seam = Color(nsColor: palette.seam)
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: seam, location: 0.15), .init(color: seam, location: 0.85), .init(color: .clear, location: 1)], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
    }
}

private struct Heading: View {
    @Environment(\.palette) private var palette
    let text: String

    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold, design: .rounded)).kerning(1.2).foregroundStyle(Color(nsColor: palette.label))
    }
}

private struct Label: View {
    @Environment(\.palette) private var palette
    let text: String

    var body: some View {
        Text(text).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(Color(nsColor: palette.ink))
    }
}

private struct Value: View {
    @Environment(\.palette) private var palette
    let text: String

    var body: some View {
        Text(text).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit().foregroundStyle(Color(nsColor: palette.label)).fixedSize()
    }
}

/// A word that acts, in ink, brightening under the pointer.
private struct TextAction: View {
    @Environment(\.palette) private var palette
    @State private var isHovered = false
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(nsColor: palette.ink).opacity(isHovered ? 1 : 0.7))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// The rail's round platform: lit from the top-left, shaded to the bottom-right, sunk flat while pressed.
private struct Platform<Mark: View>: View {
    @Environment(\.palette) private var palette
    var diameter: CGFloat = 19
    var isPressed = false
    @ViewBuilder let mark: Mark

    var body: some View {
        let isLight = (palette.chassisLit.usingColorSpace(.sRGB)?.brightnessComponent ?? 0) > 0.6
        let lift: Double = isPressed ? 0.2 : 1
        Circle()
            .fill(Color(nsColor: palette.chassisLit))
            .shadow(color: .white.opacity((isLight ? 0.8 : 0.07) * lift), radius: 1.5, x: -1.5, y: -1.5)
            .shadow(color: .black.opacity((isLight ? 0.16 : 0.5) * lift), radius: 2, x: 1.5, y: 2)
            .frame(width: diameter, height: diameter)
            .overlay(mark)
    }
}

private struct PressStyle: ButtonStyle {
    let diameter: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        Platform(diameter: diameter, isPressed: configuration.isPressed) { configuration.label }
    }
}

/// − value + on two small platforms.
private struct Steps: View {
    @Environment(\.palette) private var palette
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack(spacing: 10) {
            button(plus: false)
            Value(text: "\(Int(value))").frame(minWidth: 22)
            button(plus: true)
        }
    }

    private func button(plus: Bool) -> some View {
        let next = plus ? value + step : value - step
        return Button { value = min(max(next, range.lowerBound), range.upperBound) } label: {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 3.5)); p.addLine(to: CGPoint(x: 7, y: 3.5))
                if plus { p.move(to: CGPoint(x: 3.5, y: 0)); p.addLine(to: CGPoint(x: 3.5, y: 7)) }
            }
            .stroke(Color(nsColor: palette.ink), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            .frame(width: 7, height: 7)
        }
        .buttonStyle(PressStyle(diameter: 19))
        .disabled(!range.contains(next))
        .opacity(range.contains(next) ? 1 : 0.4)
    }
}

/// A colour shown as a disc set into a platform; clicking opens the system colour panel.
private struct Swatch: View {
    @Binding var hex: String

    var body: some View {
        Button { ColorPanelLink.shared.open(hex: hex) { hex = $0 } } label: {
            Circle().fill(Color(nsColor: NSColor(hex: hex) ?? .black)).frame(width: 13, height: 13)
        }
        .buttonStyle(PressStyle(diameter: 21))
    }
}

@MainActor
private final class ColorPanelLink: NSObject {
    static let shared = ColorPanelLink()
    private var onChange: ((String) -> Void)?

    func open(hex: String, onChange: @escaping (String) -> Void) {
        self.onChange = nil
        let panel = NSColorPanel.shared
        panel.showsAlpha = false
        panel.color = NSColor(hex: hex) ?? .black
        panel.setTarget(self)
        panel.setAction(#selector(changed(_:)))
        panel.level = .floating
        self.onChange = onChange
        panel.orderFront(nil)
    }

    @objc private func changed(_ panel: NSColorPanel) {
        onChange?(panel.color.hex)
    }
}

/// The current choice in ink with a drawn chevron; clicking lists the choices.
private struct MenuField: View {
    @Environment(\.palette) private var palette
    let title: String
    let items: [String]
    var label: (String) -> String = { $0 }
    let choose: (String) -> Void

    var body: some View {
        Menu {
            ForEach(items, id: \.self) { item in Button(label(item)) { choose(item) } }
        } label: {
            HStack(spacing: 7) {
                Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).lineLimit(1).truncationMode(.middle)
                Path { p in
                    p.move(to: CGPoint(x: 0, y: 3)); p.addLine(to: CGPoint(x: 3, y: 0)); p.addLine(to: CGPoint(x: 6, y: 3))
                    p.move(to: CGPoint(x: 0, y: 7)); p.addLine(to: CGPoint(x: 3, y: 10)); p.addLine(to: CGPoint(x: 6, y: 7))
                }
                .stroke(style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .frame(width: 6, height: 10)
            }
            .foregroundStyle(Color(nsColor: palette.ink))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(maxWidth: 200, alignment: .trailing)
    }
}

import AppKit
import SwiftTerm

final class TerminalSurface: LocalProcessTerminalViewDelegate {
    let view = LocalProcessTerminalView(frame: .zero)
    var onExit: (() -> Void)?
    var onTitleChange: ((String) -> Void)?
    var onDirectoryChange: ((String) -> Void)?
    var onRunningChange: ((Bool) -> Void)?
    private(set) var isRunning = false
    private var oscObservation: TerminalOscObservation?
    // Installing a palette clears SwiftTerm's color cache, so skip it when only other settings change.
    private var palette: [String] = []

    init() {
        view.processDelegate = self
        apply(Settings.shared.values)
        // OSC 133: C starts a command; A (next prompt) or D ends it.
        oscObservation = view.observeOscEvents(codes: [133]) { [weak self] event in
            guard let mark = event.payload.first else { return }
            let running: Bool
            switch mark {
            case UInt8(ascii: "C"): running = true
            case UInt8(ascii: "A"), UInt8(ascii: "D"): running = false
            default: return
            }
            Task { @MainActor in self?.setRunning(running) }
        }
        Task { [weak self] in
            for await values in Observations({ Settings.shared.values }) {
                guard let self else { break }
                self.apply(values)
            }
        }
    }

    private func apply(_ values: Settings.Values) {
        view.font = values.font
        if let foreground = NSColor(hex: values.foreground) { view.nativeForegroundColor = foreground }
        view.nativeBackgroundColor = values.backgroundColor
        if values.palette != palette {
            palette = values.palette
            view.installColors(palette.map(Self.color))
        }
    }

    private static func color(_ hex: String) -> SwiftTerm.Color {
        let rgb = NSColor(hex: hex) ?? .black
        let byte = { (value: CGFloat) in UInt16((value * 255).rounded()) }
        return SwiftTerm.Color(red8: byte(rgb.redComponent), green8: byte(rgb.greenComponent), blue8: byte(rgb.blueComponent))
    }

    func start() {
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["LANG"] = environment["LANG"] ?? "en_US.UTF-8"
        let shell = environment["SHELL"] ?? "/bin/zsh"
        ShellIntegration.apply(to: &environment, shell: shell)

        view.startProcess(
            executable: shell,
            args: ["-l"],
            environment: environment.map { "\($0.key)=\($0.value)" },
            currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path
        )
    }

    func terminate() {
        oscObservation?.cancel()
        view.terminate()
    }

    private func setRunning(_ running: Bool) {
        guard running != isRunning else { return }
        isRunning = running
        onRunningChange?(running)
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        onExit?()
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        onTitleChange?(title)
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        guard let directory, let path = Self.path(fromDirectoryURL: directory) else { return }
        onDirectoryChange?(path)
    }

    // OSC 7 sends file://host/path; zsh writes the path raw, so it is not percent-decoded.
    private static func path(fromDirectoryURL url: String) -> String? {
        guard url.hasPrefix("file://") else { return url.hasPrefix("/") ? url : nil }
        let rest = url.dropFirst("file://".count)
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        return String(rest[slash...])
    }
}

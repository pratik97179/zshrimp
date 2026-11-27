import AppKit

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let surface = TerminalSurface()

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "zshrimp"
        panel.hidesOnDeactivate = false
        panel.contentView = surface.view
        panel.initialFirstResponder = surface.view
        panel.center()
        super.init(window: panel)

        panel.delegate = self
        surface.onTitleChange = { [weak panel] title in panel?.title = title }
        surface.onExit = { [weak panel] in panel?.close() }
        surface.start()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func terminateSessions() {
        surface.terminate()
    }

    func windowWillClose(_ notification: Notification) {
        surface.terminate()
    }
}

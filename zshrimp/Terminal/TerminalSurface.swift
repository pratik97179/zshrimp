import AppKit
import SwiftTerm

final class TerminalSurface: LocalProcessTerminalViewDelegate {
    let view = LocalProcessTerminalView(frame: .zero)
    var onExit: (() -> Void)?
    var onTitleChange: ((String) -> Void)?

    init() {
        view.processDelegate = self
    }

    func start() {
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        environment["LANG"] = environment["LANG"] ?? "en_US.UTF-8"

        view.startProcess(
            executable: environment["SHELL"] ?? "/bin/zsh",
            args: ["-l"],
            environment: environment.map { "\($0.key)=\($0.value)" },
            currentDirectory: FileManager.default.homeDirectoryForCurrentUser.path
        )
    }

    func terminate() {
        view.terminate()
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        onExit?()
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        onTitleChange?(title)
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}

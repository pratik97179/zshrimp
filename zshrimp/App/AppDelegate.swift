import AppKit
import SwiftUI

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private var settingsWindow: NSWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.mainMenu = makeMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = MainWindowController()
        controller.showWindow(nil)
        windowController = controller
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        windowController?.terminateSessions()
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView())
            host.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: host)
            window.title = "Settings"
            window.styleMask = [.titled, .closable]
            // Stays above the terminal when it floats.
            window.level = .floating
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func makeMainMenu() -> NSMenu {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide zshrimp", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit zshrimp", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let shellMenu = NSMenu(title: "Shell")
        shellMenu.addItem(withTitle: "Split Right", action: #selector(PaneContainerView.splitRight(_:)), keyEquivalent: "d")
        shellMenu.addItem(withTitle: "Split Down", action: #selector(PaneContainerView.splitDown(_:)), keyEquivalent: "D")
        shellMenu.addItem(.separator())
        shellMenu.addItem(withTitle: "Close Pane", action: #selector(PaneContainerView.closePane(_:)), keyEquivalent: "w")
        shellMenu.addItem(.separator())
        let focusItems: [(String, Selector, Int)] = [
            ("Focus Left Pane", #selector(PaneContainerView.focusLeft(_:)), NSLeftArrowFunctionKey),
            ("Focus Right Pane", #selector(PaneContainerView.focusRight(_:)), NSRightArrowFunctionKey),
            ("Focus Pane Above", #selector(PaneContainerView.focusUp(_:)), NSUpArrowFunctionKey),
            ("Focus Pane Below", #selector(PaneContainerView.focusDown(_:)), NSDownArrowFunctionKey),
        ]
        for (title, action, key) in focusItems {
            let item = shellMenu.addItem(withTitle: title, action: action, keyEquivalent: String(Character(UnicodeScalar(key)!)))
            item.keyEquivalentModifierMask = [.command, .option]
        }

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Float on Top", action: #selector(MainWindowController.toggleFloating(_:)), keyEquivalent: "F")
        NSApp.windowsMenu = windowMenu

        let mainMenu = NSMenu()
        for menu in [appMenu, shellMenu, editMenu, windowMenu] {
            let item = NSMenuItem()
            item.submenu = menu
            mainMenu.addItem(item)
        }
        return mainMenu
    }
}

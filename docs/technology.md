# Technology

## Stack

| Area | Choice |
|---|---|
| Language | Swift 6, strict concurrency, UI on `@MainActor` |
| Window and terminal area | AppKit |
| Settings UI | SwiftUI |
| Terminal engine | SwiftTerm |
| Build | Xcode project with synchronized folders |
| Tests | Swift Testing |
| Target | macOS 26+, arm64, no app sandbox, local signing |
| Dependencies | SwiftTerm, pinned to an exact version |

## Terminal engine
- SwiftTerm provides the AppKit `TerminalView` and the PTY through `LocalProcessTerminalView`.
- The app reaches the engine only through `TerminalSurface`. An in-house engine is developed alongside SwiftTerm behind the same type, and each pane can use either one.
- The process is owned by its view. Panes are moved, never recreated.

## Floating mode
- Window: `NSPanel`, `level = .floating`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`, able to become key.
- Shows on every Space, including other apps' full-screen Spaces, and accepts keyboard input there.
- Shortcuts work without the menu bar.

## Settings
- One `Codable`, observable settings model persisted in `UserDefaults`.
- Visual settings apply live to every pane: theme and colors, font and size, background image, opacity, padding.
- Window settings: floating on/off.
- SwiftUI Settings window with sections Appearance, Font, Background, Window.
- A background image is stored as a file path.

# Architecture

One window holding many independent terminal sessions, arranged by arbitrary horizontal and vertical splits.

## Modules

```
zshushi/
  App/        lifecycle, menu commands, key equivalents
  Window/     main panel, floating mode
  Panes/      SplitTree, PaneContainerView
  Terminal/   TerminalSurface and engine implementations
  Settings/   settings model, persistence, settings window
zshushiTests/
```

Only `Terminal/` depends on a terminal engine.

## Data flow

```
command (menu / key) -> SplitTree change -> PaneContainerView relayout
process exit / title -> TerminalSurface  -> PaneContainerView -> SplitTree change
settings change      -> Settings model   -> every TerminalSurface
```

## Components

### SplitTree
Pure value type with no AppKit dependency.
```swift
indirect enum SplitNode {
    case leaf(PaneID)
    case split(Axis, ratio: Double, SplitNode, SplitNode)
}
```
Operations: `split(pane, axis)`, `close(pane)`, `setRatio`, `neighbor(of:direction)`.

### PaneContainerView
- Holds `[PaneID: TerminalSurface]`.
- Lays out frames from the tree. Draws and drags dividers.
- Moves existing views on tree change and never recreates them.
- Assigns first responder after split, close and neighbor moves.

### TerminalSurface
The boundary between the app and an engine:
- the `NSView` to place;
- process start: `$SHELL -l`, cwd `$HOME`, `TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG`;
- process termination on pane close and app quit;
- process exit and title change callbacks;
- applying visual settings.

### MainWindowController
Creates the panel and applies floating mode.

### Settings
Observable model in `UserDefaults` and a SwiftUI Settings scene. Changes apply live.

## Commands

| Shortcut | Action |
|---|---|
| Cmd-D | Split right |
| Cmd-Shift-D | Split down |
| Cmd-W | Close pane; closing the last pane closes the window |
| Cmd-Opt-Arrows | Focus neighbor |
| Cmd-Shift-F | Toggle floating |

Shortcuts take priority over terminal input.

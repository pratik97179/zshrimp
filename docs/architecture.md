# Architecture

One window holding many independent terminal sessions, arranged by arbitrary horizontal and vertical splits.

## Modules

```
zshrimp/
  App/        lifecycle, menu commands, key equivalents
  Window/     main panel, floating mode
  Panes/      SplitTree, PaneContainerView, PaneView, Elevation
  Terminal/   TerminalSurface and engine implementations
  Settings/   settings model, persistence, settings window
zshrimpTests/
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
- Lays out frames from the tree with an `Elevation.gap` between panes and around the edges, below the transparent title bar. The gap is the divider's grab area.
- Fills the workspace behind the panes with the background image, or the theme background shifted toward the foreground.
- Tells each pane whether it has focus. A pane tracks hover itself.
- Moves existing views on tree change and never recreates them.
- Assigns first responder after split, close and neighbor moves.

### PaneView
- Wraps one terminal view, inset by the padding.
- Fills the padding ring and draws a hairline edge, rounded at a radius that keeps the terminal's corners inside, so nothing clips the terminal.
- The focused pane is at full strength, with a light rim brightest along its top edge.
- Every other pane fades toward its background under a veil and loses most of its color through a grey layer in saturation blend mode. Hover lifts both halfway.
- Animates only layer opacity: a quick spring when a pane lights up, a slow settle when it loses focus, a fast release when the pointer leaves.

### Elevation
Tokens for gap, corner radius (concentric with the window's 16pt corners), the look of each pane state and its animation pace. `ElevationPalette` derives the workspace, veil and rim colors from the theme.

### TerminalSurface
The boundary between the app and an engine:
- the `NSView` to place;
- process start: `$SHELL -l`, cwd `$HOME`, `TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG`;
- zsh shell integration (`ShellIntegration`): zsh starts with `ZDOTDIR` set to `~/Library/Application Support/zshrimp/zsh`, whose `.zshenv` restores the user's `ZDOTDIR`, sources their `.zshenv` and adds hooks that send OSC 133 `A` at each prompt and `C` before each command;
- process termination on pane close and app quit;
- process exit, title change and running change callbacks; `isRunning` is set by OSC 133 `C` and cleared by `A` or `D`, observed through SwiftTerm's `observeOscEvents`;
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

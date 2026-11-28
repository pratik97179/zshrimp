# Architecture

One window holding many independent terminal sessions, arranged by arbitrary horizontal and vertical splits.

## Modules

```
zshrimp/
  App/        lifecycle, menu commands, key equivalents, chrome typography
  Window/     chassis window, rail, floating mode
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
- Is the pit: one sunken surface with 14pt corners that clip everything inside it. Panes fill it edge to edge, with no gaps.
- Fills the pit with the background image, or the terminal background, so panes have no edges of their own.
- Draws over the panes (`PitOverlay`, which takes no clicks) a seam of light at each divider, covering the middle 60% of the split and fading out toward both ends, and a shade cast inward from the pit's rim, deepest under its top edge.
- An 8pt band centered on each seam is the divider's grab area. Dragging it resizes the panes live.
- Tells each pane whether it has focus. A pane tracks hover itself.
- Moves existing views on tree change and never recreates them.
- Assigns first responder after split, close and neighbor moves.

### PaneView
- Wraps one terminal view, inset by the padding, below a header.
- The header shows the pane's directory, `~` for home and truncated from the start, and a dot in the theme's green while a command runs. Clicking it focuses the pane.
- Has no fill, outline or edge; it is told apart from its neighbors only by the seams.
- The focused pane is at full strength.
- Every other pane fades toward its background under a veil and loses most of its color through a grey layer in saturation blend mode. Hover lifts both halfway.
- Animates only layer opacity: a quick spring when a pane lights up, a slow settle when it loses focus, a fast release when the pointer leaves.

### Elevation
Tokens for the pit's corner radius (concentric with the window's 26pt trailing corners), how far seams fade, the look of each pane state and its animation pace. `ElevationPalette` derives the pit, shade, seam, veil, chassis and rail colors from the theme.

### TerminalSurface
The boundary between the app and an engine:
- the `NSView` to place;
- process start: `$SHELL -l`, cwd `$HOME`, `TERM=xterm-256color`, `COLORTERM=truecolor`, `LANG`;
- zsh shell integration (`ShellIntegration`): zsh starts with `ZDOTDIR` set to `~/Library/Application Support/zshrimp/zsh`, whose `.zshenv` restores the user's `ZDOTDIR`, sources their `.zshenv` and adds hooks that send OSC 7 with the directory and OSC 133 `A` at each prompt, and OSC 133 `C` before each command;
- process termination on pane close and app quit;
- process exit, title, directory and running change callbacks; the directory comes from OSC 7; `isRunning` is set by OSC 133 `C` and cleared by `A` or `D`, observed through SwiftTerm's `observeOscEvents`;
- applying visual settings.

### MainWindowController
Creates the window and applies floating mode.

### ChassisWindow
- A borderless, resizable panel. `ChassisView` masks it to its silhouette: 30pt corners on the rail side, 26pt on the right. The system shadow follows that shape.
- The body is shaded lighter toward the rail, with a hairline highlight along the top and left edges that fades out toward the bottom right.
- Lays out `SpineView` along the left edge and the pane workspace inset beside it.

### SpineView
- The rail: window controls stacked at the top, the app name set vertically, and layout glyphs at the bottom.
- The rail is 44pt wide. Each control (`RailControls.swift`) is an outlined ink mark on a round 19pt platform, softly raised: a light glint to the top-left and a soft shade to the bottom-right. Pressing sinks the platform flat. Marks are quiet at rest and ease to full ink near the pointer.
- Close, minimize and resize stack at the top: a rounded cross that turns vermilion under the pointer, a bar, and a two-headed diagonal arrow.
- Split right, split down and float sit at the bottom as outlined windows: divided down the middle, divided across, and one window lifted off another that rises further while floating. They send their actions up the responder chain, so they reach the focused pane.
- Without a title bar AppKit's close, minimize and zoom only beep, so `ChassisWindow` implements them: close asks the delegate first, zoom toggles between the screen's visible frame and the previous frame.
- Dragging the rail moves the window; double-clicking it zooms.
- Chrome text is set in SF Pro Rounded (`Typography`): the rail name in 15pt semibold, spaced 2.5pt and reading bottom to top; pane header labels in 11pt medium; the Settings form in the rounded design. Terminal text keeps the monospaced face chosen in Settings.
- Settings opens in its own `ChassisWindow`, fixed in size, with a rail that only closes it (Escape closes it too) and the name "settings". The form sits in a pit like the terminals'. It has no cards: lowercase headings stand to the left, and rows are parted by the same faded seams as panes. Steppers and colour swatches sit on the rail's round platforms, menus show the choice in ink with a drawn chevron, and actions are plain words.
- The app quits when the main window closes. AppKit's last-window rule is off: it ignores panels, so closing any other window, even a tooltip, would otherwise quit the app.

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

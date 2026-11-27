# zshrimp

**A native macOS terminal built for splitting and floating.**

---

## The idea

Many terminal sessions in one window.
Split them any way you like.
Pin the whole window above everything, on every Space.

---

## Who it is for

People who keep several terminals open at once:

- a shell, an editor and a log tail side by side;
- coding-agent CLIs running next to the code they change;
- a terminal that stays in view while another app is full screen.

---

## Splits

- Split any pane right or down, as many times as needed.
- Every pane is an independent session with its own shell.
- Drag dividers to resize.
- Restructuring the layout never restarts a session. Running programs keep running.
- Closing the last pane closes the window.

---

## Floating mode

- One shortcut pins the window above all other windows.
- It shows on every Space, including other apps' full-screen Spaces.
- It accepts keyboard input there.

---

## A real terminal

- Full-screen TUIs: `vim`, `htop`, `tmux` and coding-agent CLIs.
- TrueColor and 256 colors.
- Mouse scroll, multi-line paste, live resize.
- Emoji, CJK and IME input.
- Each pane starts a login shell in your home folder.

---

## Keyboard first

| Shortcut | Action |
|---|---|
| Cmd-D | Split right |
| Cmd-Shift-D | Split down |
| Cmd-W | Close pane |
| Cmd-Opt-Arrows | Move focus to the neighboring pane |
| Cmd-Shift-F | Toggle floating |

Shortcuts always win over terminal input.

---

## Make it yours

Changes apply live to every pane:

- theme and colors;
- font and size;
- background image and opacity;
- padding;
- floating on or off.

---

## Native

- Built in Swift with AppKit and SwiftUI.
- Made for macOS on Apple silicon.
- No web views. One small dependency.

---

## zshrimp

Many sessions. Any split. Always on top.

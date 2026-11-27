# Testing

## Automated
```
xcodebuild -project zshushi.xcodeproj -scheme zshushi -destination 'platform=macOS' build
xcodebuild -project zshushi.xcodeproj -scheme zshushi -destination 'platform=macOS' test
```
Unit tests cover `SplitTree`.

## Manual

### Terminal fidelity
Run coding-agent CLIs, `vim`, `htop` and `tmux`, and check:
- Shift+Enter newline, multi-line paste, mouse scroll, resize while running.
- Emoji and CJK width, Japanese IME, Option as Meta.

### Floating mode
Switch Spaces, enter another app's full-screen Space and open Mission Control. The window is visible in each and accepts keyboard input.

### Session stability
Run `top` in a pane. Split, close siblings and resize 20 times. The PID stays the same and output continues.

### Performance
Run `yes | head -c 200M` in six panes. Watch CPU and dropped frames. Launch with `-NSAppSleepDisabled YES` to rule out App Nap.

### Process cleanup
After closing panes and after quitting, `ps` shows no remaining shells or child processes.

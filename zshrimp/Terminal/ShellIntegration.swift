import Foundation

/// Makes zsh mark its prompt with OSC 133, so a resize leaves the prompt rows for zsh to redraw.
/// zsh starts with ZDOTDIR pointing at a folder whose .zshenv puts the user's ZDOTDIR back,
/// loads their .zshenv, and adds the hooks; zsh then reads the user's other dotfiles as usual.
enum ShellIntegration {
    private static let zshenv = #"""
    if [[ -n $ZSHRIMP_ZDOTDIR ]]; then ZDOTDIR=$ZSHRIMP_ZDOTDIR; else unset ZDOTDIR; fi
    unset ZSHRIMP_ZDOTDIR
    [[ -f ${ZDOTDIR:-$HOME}/.zshenv ]] && source ${ZDOTDIR:-$HOME}/.zshenv
    if [[ -o interactive ]]; then
      _zshrimp_prompt_start() { print -n '\e]133;A\a' }
      _zshrimp_command_start() { print -n '\e]133;C\a' }
      autoload -Uz add-zsh-hook
      add-zsh-hook precmd _zshrimp_prompt_start
      add-zsh-hook preexec _zshrimp_command_start
    fi
    """#

    private static let zdotdir: URL? = {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "zshrimp/zsh", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try zshenv.write(to: folder.appending(path: ".zshenv"), atomically: true, encoding: .utf8)
            return folder
        } catch {
            return nil
        }
    }()

    static func apply(to environment: inout [String: String], shell: String) {
        guard (shell as NSString).lastPathComponent == "zsh", let zdotdir else { return }
        if let userZdotdir = environment["ZDOTDIR"] {
            environment["ZSHRIMP_ZDOTDIR"] = userZdotdir
        }
        environment["ZDOTDIR"] = zdotdir.path
    }
}

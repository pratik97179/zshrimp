nonisolated struct Theme: Identifiable {
    let name: String
    let foreground: String
    let background: String
    /// The 16 ANSI colors: normal 0–7, then bright 8–15.
    let palette: [String]

    var id: String { name }

    static let all = [
        Theme(
            name: "Default", foreground: "#D9D9D9", background: "#000000",
            palette: ["#000000", "#C23621", "#25BC24", "#ADAD27", "#492EE1", "#D338D3", "#33BBC8", "#CBCCCD",
                      "#818383", "#FC391F", "#31E722", "#EAEC23", "#5833FF", "#F935F8", "#14F0F0", "#E9EBEB"]
        ),
        Theme(
            name: "Solarized Dark", foreground: "#839496", background: "#002B36",
            palette: ["#073642", "#DC322F", "#859900", "#B58900", "#268BD2", "#D33682", "#2AA198", "#EEE8D5",
                      "#002B36", "#CB4B16", "#586E75", "#657B83", "#839496", "#6C71C4", "#93A1A1", "#FDF6E3"]
        ),
        Theme(
            name: "Solarized Light", foreground: "#657B83", background: "#FDF6E3",
            palette: ["#073642", "#DC322F", "#859900", "#B58900", "#268BD2", "#D33682", "#2AA198", "#EEE8D5",
                      "#002B36", "#CB4B16", "#586E75", "#657B83", "#839496", "#6C71C4", "#93A1A1", "#FDF6E3"]
        ),
        Theme(
            name: "Dracula", foreground: "#F8F8F2", background: "#282A36",
            palette: ["#21222C", "#FF5555", "#50FA7B", "#F1FA8C", "#BD93F9", "#FF79C6", "#8BE9FD", "#F8F8F2",
                      "#6272A4", "#FF6E6E", "#69FF94", "#FFFFA5", "#D6ACFF", "#FF92DF", "#A4FFFF", "#FFFFFF"]
        ),
        Theme(
            name: "Nord", foreground: "#D8DEE9", background: "#2E3440",
            palette: ["#3B4252", "#BF616A", "#A3BE8C", "#EBCB8B", "#81A1C1", "#B48EAD", "#88C0D0", "#E5E9F0",
                      "#4C566A", "#BF616A", "#A3BE8C", "#EBCB8B", "#81A1C1", "#B48EAD", "#8FBCBB", "#ECEFF4"]
        ),
        Theme(
            name: "Gruvbox Dark", foreground: "#EBDBB2", background: "#282828",
            palette: ["#282828", "#CC241D", "#98971A", "#D79921", "#458588", "#B16286", "#689D6A", "#A89984",
                      "#928374", "#FB4934", "#B8BB26", "#FABD2F", "#83A598", "#D3869B", "#8EC07C", "#EBDBB2"]
        ),
    ]
}

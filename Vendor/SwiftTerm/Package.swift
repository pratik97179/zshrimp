// swift-tools-version:6.2

// SwiftTerm 1.99.4 (b30669619244453a66b14a6b10ec859e3016d6fd) without its build plugin.
// Sources/SwiftTerm/Generated holds the plugin's output for that commit.

import PackageDescription

let package = Package(
    name: "SwiftTerm",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "SwiftTerm", targets: ["SwiftTerm"]),
    ],
    targets: [
        .target(
            name: "SwiftTerm",
            path: "Sources/SwiftTerm",
            exclude: [
                "Mac/README.md",
                "Apple/Metal/Shaders.metal",
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

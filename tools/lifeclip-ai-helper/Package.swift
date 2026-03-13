// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "lifeclip-ai-helper",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "lifeclip-ai-helper",
            path: "Sources"
        ),
    ]
)

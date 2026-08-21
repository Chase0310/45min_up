// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "StandUp",
    platforms: [.macOS(.v14)], // symbolEffect（Apple 预制符号动效）需要 macOS 14
    targets: [
        .target(
            name: "StandUpCore",
            path: "Sources/StandUpCore"
        ),
        .executableTarget(
            name: "StandUp",
            dependencies: ["StandUpCore"],
            path: "Sources/StandUp"
        ),
        // CLT 环境下 SwiftPM 的 swift-testing 集成不执行测试（静默 0 个），
        // 因此测试用自包含微壳可执行 target：swift run CoreTests，非零退出码即红。
        .executableTarget(
            name: "CoreTests",
            dependencies: ["StandUpCore"],
            path: "Tests/CoreTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)

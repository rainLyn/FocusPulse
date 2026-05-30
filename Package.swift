// swift-tools-version: 5.9
// ═════════════════════════════════════════════════════════
//  FocusPulse — 专注计时 + 时间统计
//  零第三方依赖，全 Apple SDK 原生实现
//
//  FocusPulseCore: 可测试的核心逻辑（Domain + Data）
//  FocusPulse:     完整 iOS App（依赖 Core）
// ═════════════════════════════════════════════════════════
import PackageDescription

let package = Package(
    name: "FocusPulse",
    defaultLocalization: "zh",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FocusPulseCore", targets: ["FocusPulseCore"]),
        .library(name: "FocusPulse", targets: ["FocusPulse"]),
    ],
    targets: [
        .target(name: "FocusPulseCore", path: "Sources/Core"),
        .target(
            name: "FocusPulse",
            dependencies: ["FocusPulseCore"],
            path: "Sources",
            exclude: ["Core"]
        ),
        .testTarget(
            name: "FocusPulseTests",
            dependencies: ["FocusPulseCore"],
            path: "Tests"
        ),
    ]
)

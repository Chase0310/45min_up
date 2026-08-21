# 原生 Swift + AppKit 刘海窗口，而非 Tauri/Electron

本应用的核心能力是在刘海上方悬浮一个跨越所有桌面空间（含全屏应用之上）的常驻窗口，这属于 AppKit 层的底层窗口控制（`NSWindow` level、collectionBehavior、刘海安全区坐标），Swift 是唯一的一等公民调用方。Tauri 的窗口 API 不覆盖这些行为，需要 Rust→AppKit FFI 绕道，且本机未装 Rust 工具链；Electron 的 WebView 常驻开销对一个 8 小时后台运行的工具不可接受。本机已有 Swift 6.2（Command Line Tools，无完整 Xcode），用 SPM 构建 + 脚本组装 .app + ad-hoc 签名即可本地运行。

## Considered Options

- **原生 Swift（SPM + AppKit/SwiftUI）** ✅ — 窗口控制直接、零新增工具链、常驻内存 ~30-50MB
- **Tauri** — 需安装 Rust；最难的刘海窗口部分反而要写 FFI；WebView 常驻 ~150MB+
- **Electron** — 体积与内存对常驻工具不可接受

## Consequences

- 仅限 Apple 平台（本产品只面向 macOS，接受）
- 无完整 Xcode：不能出 Xcode 工程/上架公证，仅本地分发（符合预期）

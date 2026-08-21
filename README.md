# 45min Up 🧍

在 MacBook 刘海里常驻的久坐提醒：平时显示倒计时，每 45 分钟（可调 5–240）提醒你站起来，点「我站起来了」重新计时。

## 功能

- **刘海倒计时**：常驻 `mm:ss`，随时可见剩余时间
- **站立提醒**：间隔归零时刘海展开横幅 + 提示音 + 系统通知兜底（外接屏/极端全屏场景）
- **确认 / 稍后**：「我站起来了」归零重计；「稍后 5 分钟」再提醒
- **滚动计时**：从确认那一刻起算，不对齐墙钟
- **智能暂停**：合盖/锁屏/睡眠自动暂停，唤醒续走；支持手动会议暂停
- **点击刘海**弹出设置：预设 20/30/45/60 + 5 分钟步进自定义
- **无 Dock 图标**，菜单栏 🧍 图标兜底，支持开机自启动

## 构建与运行

需要：macOS 13+，Xcode Command Line Tools（无需完整 Xcode）

```bash
./scripts/build-app.sh   # swift build -c release + 组装 .app + ad-hoc 签名
open "build/45min Up.app"
```

首次启动会请求通知授权（兜底通道用，建议允许）。
想开机自启动：点刘海 → 设置 → 「开机自启动：开」。

## 开发

```bash
swift run CoreTests   # 引擎测试（CLT 下 swift-testing 不执行，用自包含微壳，非零退出码=红）
swift build           # 增量编译
```

架构见 [docs/adr/0001](docs/adr/0001-native-swift-appkit-notch-window.md)，术语表见 [CONTEXT.md](CONTEXT.md)。

- `Sources/StandUpCore/` — `ReminderEngine` 纯状态机（计时语义全在这，测试覆盖）
- `Sources/StandUp/` — AppKit 外壳：刘海面板、SwiftUI 内容、菜单栏、通知、睡眠监听

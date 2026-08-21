import AppKit
import ServiceManagement
import StandUpCore
import UserNotifications

/// 引擎与 UI 之间的桥：驱动 tick、响应事件（提示音/系统通知/横幅）、暴露面板模式。
final class AppState: ObservableObject {
    enum PanelMode: Equatable {
        case compact   // 刘海内倒计时
        case reminder  // 站立提醒横幅
        case settings  // 设置面板
    }

    private(set) var store: SettingsStore
    private(set) var engine: ReminderEngine
    private var userPaused = false

    @Published private(set) var remaining: TimeInterval
    @Published private(set) var engineState: ReminderEngine.State
    @Published var panelMode: PanelMode = .compact
    @Published private(set) var intervalMinutes: Double
    @Published var launchAtLogin = false
    /// 刘海开孔高度（其上无物理像素）——紧凑模式内容要画在这条线以下
    @Published var notchHeight: CGFloat = 32

    init(store: SettingsStore) {
        self.store = store
        let minutes = store.intervalMinutes
        self.engine = ReminderEngine(interval: minutes * 60, now: Date())
        self.remaining = engine.remaining
        self.engineState = engine.state
        self.intervalMinutes = minutes
    }

    func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func tick(now: Date = Date()) {
        let events = engine.advance(to: now)
        sync()
        if events.contains(.reminderStarted) {
            panelMode = .reminder
            Sound.play()
            postNotificationFallback()
        }
    }

    // MARK: - 用户动作

    func acknowledge() {
        engine.acknowledge(now: Date())
        panelMode = .compact
        sync()
    }

    func snooze() {
        engine.snooze(now: Date())
        panelMode = .compact
        sync()
    }

    func togglePause() {
        if engine.state == .paused {
            userPaused = false
            engine.resume(now: Date())
        } else if engine.pause(now: Date()) {
            // 只有真的暂停成功才记账，避免提醒态误置标志、唤醒后被卡在暂停
            userPaused = true
        }
        sync()
    }

    func setInterval(minutes: Double) {
        // 5–240 收敛在唯一的写入边界做，视图层不必各自防御
        let clamped = min(240, max(5, minutes))
        intervalMinutes = clamped
        store.intervalMinutes = clamped
        userPaused = false // 整轮重置 = 全新开始，不带旧暂停语义
        engine.setInterval(clamped * 60, now: Date())
        sync()
    }

    func toggleSettings() {
        panelMode = panelMode == .settings ? .compact : .settings
    }

    func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("45min Up: 登录项操作失败 \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - 系统睡眠：睡眠即暂停，唤醒续走；手动暂停不被唤醒覆盖

    func systemSleep() {
        if engine.state == .counting {
            engine.pause(now: Date())
            sync()
        }
    }

    func systemWake() {
        if engine.state == .paused && !userPaused {
            engine.resume(now: Date())
            sync()
        }
    }

    // MARK: - 私有

    private func sync() {
        remaining = engine.remaining
        engineState = engine.state
    }

    private func postNotificationFallback() {
        let content = UNMutableNotificationContent()
        content.title = "45min Up"
        content.body = "该站起来活动一下了 💪"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "stand-reminder-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

enum Sound {
    static func play() {
        if let sound = NSSound(named: "Glass") ?? NSSound(named: "Tink") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}

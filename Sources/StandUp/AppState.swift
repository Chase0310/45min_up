import AppKit
import ServiceManagement
import StandUpCore
import SwiftUI
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
    /// 鼠标是否悬停在紧凑区（悬停才显示数字）
    @Published var hovered = false
    /// 线条基础色（用户 DIY，写入即持久化）
    @Published var chinColor: Color {
        didSet { store.accentHex = chinColor.hexString }
    }
    /// 线条与刘海底缘的间隙（pt，用户实时可调）
    @Published var notchGap: Double {
        didSet { store.notchGap = notchGap }
    }
    /// 站立休息时长（分钟，写入即持久化，休息中即时生效）
    @Published var breakMinutes: Double {
        didSet {
            store.breakMinutes = breakMinutes
            engine.setBreakInterval(breakMinutes * 60, now: Date())
        }
    }

    /// 剩余进度 0…1（进度线宽度用）
    var progressFraction: Double {
        let total = engine.interval > 0 ? engine.interval : 1
        return min(1, max(0, remaining / total))
    }

    var isOnBreak: Bool { engineState == .breaking }

    /// 休息剩余进度 0…1
    var breakFraction: Double {
        let total = engine.breakInterval > 0 ? engine.breakInterval : 1
        return min(1, max(0, engine.breakRemaining / total))
    }


    init(store: SettingsStore) {
        self.store = store
        let minutes = store.intervalMinutes
        self.engine = ReminderEngine(
            interval: minutes * 60,
            breakInterval: store.breakMinutes * 60,
            now: Date()
        )
        self.remaining = engine.remaining
        self.engineState = engine.state
        self.intervalMinutes = minutes
        self.chinColor = Color(hex: store.accentHex)
        self.notchGap = store.notchGap
        self.breakMinutes = store.breakMinutes
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
            hovered = false
            panelMode = .reminder
            Sound.play()
            postNotificationFallback()
        }
        if events.contains(.breakEnded) {
            // 休息结束：轻提示音即可，不开横幅（白噪音哲学：下一轮悄悄开始）
            Sound.playBreakEnd()
        }
    }

    func setHover(_ on: Bool) {
        guard panelMode == .compact, hovered != on else { return }
        hovered = on
    }

    /// 菜单栏「打开设置」入口（悬停态不外带）
    func openSettings() {
        hovered = false
        panelMode = .settings
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

    /// 重新计时：不管进行到哪，当前间隔从头再来
    func restartRound() {
        userPaused = false
        engine.setInterval(engine.interval, now: Date())
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
        hovered = false
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
        // 裸二进制（调试快照）没有 bundle，UNUserNotificationCenter 会抛
        // bundleProxyForCurrentProcess 异常，直接跳过
        guard Bundle.main.bundleIdentifier != nil else { return }
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

    /// 休息结束的轻提示（比提醒音温和）
    static func playBreakEnd() {
        if let sound = NSSound(named: "Tink") ?? NSSound(named: "Glass") {
            sound.volume = 0.5
            sound.play()
        }
    }
}

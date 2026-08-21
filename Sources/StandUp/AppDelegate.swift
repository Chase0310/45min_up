import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var app: AppState!
    private var panel: NotchPanel!
    private var statusItem: NSStatusItem!
    private var pauseMenuItem: NSMenuItem!
    private var loginMenuItem: NSMenuItem!
    private var cancellables: Set<AnyCancellable> = []
    private var workspaceObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 调试快照：离屏渲染紧凑模式 UI 到 /tmp/fuse_debug.png（系统对开孔区的截图遮罩
        // 让屏上截图无法验证该区域，cacheDisplay 绕过合成器直接取 SwiftUI 内容）
        if ProcessInfo.processInfo.environment["STANDUP_DEBUG_SNAPSHOT"] == "1" {
            DebugSnapshot.writeCompact()
            NSApp.terminate(nil)
            return
        }

        app = AppState(store: SettingsStore())

        panel = NotchPanel()
        panel.contentView = NSHostingView(rootView: NotchView(app: app))
        panel.orderFrontRegardless()
        relayout()

        app.startTimer()
        installStatusItem()
        installObservers()
        requestNotificationAuthorization()
        app.launchAtLogin = SMAppService.mainApp.status == .enabled
        refreshMenuTitles()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    // MARK: - 布局

    private func relayout() {
        guard let screen = notchScreen() else {
            panel.placeFallback(on: NSScreen.main)
            return
        }
        let rect = notchRect(on: screen)
        app.notchHeight = rect.height
        panel.place(
            mode: app.panelMode,
            notchRect: rect,
            screenFrame: screen.frame,
            hovered: app.hovered
        )
    }

    private func installObservers() {
        app.$panelMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.relayout() }
            .store(in: &cancellables)

        app.$hovered
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.relayout() }
            .store(in: &cancellables)

        app.$engineState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshMenuTitles() }
            .store(in: &cancellables)

        // 屏幕参数变化（接显示器、改缩放）时重新定位
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.relayout() }
            .store(in: &cancellables)

        // 睡眠/唤醒、锁屏/解锁 → 暂停/续走
        let ws = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            ws.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) {
                [weak self] _ in self?.app.systemSleep()
            },
            ws.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
                [weak self] _ in self?.app.systemWake()
            },
            ws.addObserver(
                forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.app.systemSleep() },
            ws.addObserver(
                forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in self?.app.systemWake() },
        ]
    }

    // MARK: - 菜单栏兜底入口

    private func installStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "figure.stand",
            accessibilityDescription: "45min Up"
        )

        let menu = NSMenu()

        let settingsItem = NSMenuItem(
            title: "打开设置", action: #selector(openSettings(_:)), keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        pauseMenuItem = NSMenuItem(
            title: "暂停", action: #selector(togglePause(_:)), keyEquivalent: "p"
        )
        pauseMenuItem.target = self
        menu.addItem(pauseMenuItem)

        loginMenuItem = NSMenuItem(
            title: "开机自启动", action: #selector(toggleLogin(_:)), keyEquivalent: "l"
        )
        loginMenuItem.target = self
        menu.addItem(loginMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "退出 45min Up",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )

        statusItem.menu = menu
    }

    private func refreshMenuTitles() {
        pauseMenuItem?.title = app.engineState == .paused ? "继续" : "暂停"
        loginMenuItem?.state = app.launchAtLogin ? .on : .off
    }

    @objc private func openSettings(_ sender: Any?) {
        app.openSettings()
    }

    @objc private func togglePause(_ sender: Any?) {
        app.togglePause()
    }

    @objc private func toggleLogin(_ sender: Any?) {
        app.toggleLaunchAtLogin()
        refreshMenuTitles()
    }

    // MARK: - 通知兜底授权

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) {
            granted, error in
            if let error { NSLog("45min Up: 通知授权失败 \(error.localizedDescription)") }
            if !granted { NSLog("45min Up: 通知未授权，兜底通道不可用（刘海提醒不受影响）") }
        }
    }
}

enum DebugSnapshot {
    static func writeCompact() {
        let state = AppState(store: SettingsStore())
        state.notchHeight = 32
        let size = NSSize(width: 185, height: 62) // 32 开孔 + 3 间隙 + 3.5 线 + 数字区
        let view = NSHostingView(
            rootView: NotchView(app: state).frame(width: size.width, height: size.height)
        )
        view.frame = NSRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()

        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width) * 2,
            pixelsHigh: Int(size.height) * 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        bitmap.size = size
        view.cacheDisplay(in: view.bounds, to: bitmap)

        let png = bitmap.representation(using: .png, properties: [:])!
        try? png.write(to: URL(fileURLWithPath: "/tmp/fuse_debug.png"))
        NSLog("45min Up: 调试快照已写入 /tmp/fuse_debug.png")
    }
}

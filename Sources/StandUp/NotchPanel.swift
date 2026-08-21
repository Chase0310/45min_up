import AppKit

/// 刘海区域的无边框面板：状态栏层级、跨所有空间、全屏之上可见。
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        level = .statusBar
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
        ]
    }

    override var canBecomeKey: Bool { true }

    /// 关键：默认实现会把窗口压到菜单栏之下（这正是首版面板浮在刘海下面的原因）。
    /// 刘海面板必须允许顶到屏幕最上沿，原样返回。
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// 按模式落位：紧凑=精确覆盖刘海；展开=以屏幕水平中心对齐、顶边贴屏幕顶端向下伸展。
    func place(mode: AppState.PanelMode, notchRect: CGRect, screenFrame: CGRect) {
        let rect: NSRect
        switch mode {
        case .compact:
            rect = notchRect
        case .reminder, .settings:
            let size = expandedSize(for: mode)
            rect = NSRect(
                x: (screenFrame.midX - size.width / 2).rounded(),
                y: screenFrame.maxY - size.height,
                width: size.width,
                height: size.height
            )
        }
        setFrame(rect, display: true)
    }

    /// 无刘海机器（或只剩外接屏）时的退化：给定屏幕顶端正下方居中
    func placeFallback(on screen: NSScreen?) {
        guard let frame = screen?.frame else { return }
        let size = NSSize(width: 200, height: 34)
        setFrame(
            NSRect(
                x: (frame.midX - size.width / 2).rounded(),
                y: frame.maxY - size.height,
                width: size.width,
                height: size.height
            ),
            display: true
        )
    }

    private func expandedSize(for mode: AppState.PanelMode) -> NSSize {
        switch mode {
        case .compact: return NSSize(width: 0, height: 0)
        case .reminder: return NSSize(width: 420, height: 118)
        case .settings: return NSSize(width: 420, height: 190)
        }
    }
}

/// 有刘海的内置屏幕
func notchScreen() -> NSScreen? {
    NSScreen.screens.first {
        $0.auxiliaryTopLeftArea != nil && $0.auxiliaryTopRightArea != nil
    }
}

/// 刘海本体的矩形（两侧安全区之间的空档）
func notchRect(on screen: NSScreen) -> CGRect {
    guard
        let left = screen.auxiliaryTopLeftArea,
        let right = screen.auxiliaryTopRightArea
    else { return .zero }
    return CGRect(
        x: left.maxX,
        y: left.minY,
        width: right.minX - left.maxX,
        height: left.height
    )
}

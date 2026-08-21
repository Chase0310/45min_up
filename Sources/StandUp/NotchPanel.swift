import AppKit
import SwiftUI

/// 非激活窗口的第一次点击默认只激活窗口、不投递给内容
/// （这就是"要点两下"的根源）——必须显式接受首击
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

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

    /// 单击直通：面板级 mouseDown 直接回调，不经过 SwiftUI 手势
    /// （非激活面板上 SwiftUI tap 常吃掉第一次点击，体验成"双击才能打开"）
    var onMouseDown: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }

    /// 关键：默认实现会把窗口压到菜单栏之下（这正是首版面板浮在刘海下面的原因）。
    /// 刘海面板必须允许顶到屏幕最上沿，原样返回。
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// 按模式落位。
    /// 紧凑 = 刘海矩形 + 悬停区（刘海开孔没有物理像素，进度线画在下伸的真实像素区，
    /// 悬停时区域从 idleHeight 伸到 expandedHeight 露出数字）；
    /// 展开 = 以屏幕水平中心对齐、顶边贴屏幕顶端向下伸展。
    func place(
        mode: AppState.PanelMode,
        notchRect: CGRect,
        screenFrame: CGRect,
        hovered: Bool,
        gap: Double
    ) {
        let rect: NSRect
        switch mode {
        case .compact:
            // 条高 = 间隙 + 6pt 线 + 余量；悬停碗腔内多一行数字
            let strip = hovered
                ? CGFloat(gap) + Self.bowlHeight + 20
                : CGFloat(gap) + Self.bowlHeight + 3
            let height = notchRect.height + strip
            rect = NSRect(
                x: notchRect.minX,
                y: notchRect.maxY - height,
                width: notchRect.width,
                height: height
            )
        case .reminder, .settings:
            let size = expandedSize(for: mode)
            rect = NSRect(
                x: (screenFrame.midX - size.width / 2).rounded(),
                y: screenFrame.maxY - size.height,
                width: size.width,
                height: size.height
            )
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            self.animator().setFrame(rect, display: true)
        }
    }

    static let bowlHeight: CGFloat = 6

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
        case .reminder: return NSSize(width: 420, height: 140)
        case .settings: return NSSize(width: 420, height: 300)
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

import SwiftUI

struct NotchView: View {
    @ObservedObject var app: AppState

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NotchShape())
            .animation(.easeInOut(duration: 0.2), value: app.panelMode)
    }

    @ViewBuilder
    private var content: some View {
        switch app.panelMode {
        case .compact: CompactCountdown(app: app)
        case .reminder: ReminderBanner(app: app)
        case .settings: SettingsPanel(app: app)
        }
    }
}

/// 上边直角、下边大圆角的黑色底（顶部与屏幕顶端齐平，视觉上像刘海的延伸）
private struct NotchShape: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let radius: CGFloat = 14
                let w = geo.size.width
                let h = geo.size.height
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: h - radius))
                path.addQuadCurve(
                    to: CGPoint(x: w - radius, y: h),
                    control: CGPoint(x: w, y: h)
                )
                path.addLine(to: CGPoint(x: radius, y: h))
                path.addQuadCurve(to: CGPoint(x: 0, y: h - radius), control: CGPoint(x: 0, y: h))
                path.closeSubpath()
            }
            .fill(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 0) // 描边只画下缘方向，弱化
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .mask(
                        LinearGradient(
                            colors: [.clear, .white],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
        }
    }
}

/// 紧凑模式：刘海下缘的蓝色进度线（随剩余时间收缩），悬停露出数字，点击打开设置
private struct CompactCountdown: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: app.notchHeight) // 开孔区，无像素
            ZStack(alignment: .top) {
                CountdownFuse(
                    progress: app.progressFraction,
                    paused: app.engineState == .paused
                )
                .frame(height: 12)

                Group {
                    if app.engineState == .paused {
                        Text("⏸ \(app.remaining.clockString)")
                    } else {
                        Text(app.remaining.clockString)
                    }
                }
                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundColor(.white)
                .padding(.top, 7)
                .opacity(app.hovered ? 1 : 0)
                .animation(.easeOut(duration: 0.15), value: app.hovered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .contentShape(Rectangle())
        .onTapGesture { app.toggleSettings() }
        .onHover { app.setHover($0) }
    }
}

/// 电光蓝保险丝：深蓝→亮青渐变线随剩余时间收缩，白色燃点 + 青色光晕 + 流动高光
private struct CountdownFuse: View {
    var progress: Double
    var paused: Bool

    @State private var shimmerOn = false

    // 固定电光蓝，不跟随系统强调色（Graphite 用户会得到一根黑线）
    private static let blueDeep = Color(red: 0.04, green: 0.4, blue: 1.0)
    private static let blueNeon = Color(red: 0, green: 0.78, blue: 1.0)

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width * progress, 4)
            ZStack(alignment: .leading) {
                // 全宽轨道（微蓝，作满刻度参照）
                Capsule().fill(Self.blueNeon.opacity(0.14))
                // 燃烧中的亮线
                ZStack(alignment: .trailing) {
                    Capsule().fill(
                        LinearGradient(
                            colors: [Self.blueDeep, Self.blueNeon],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    // 白热燃点
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                        .shadow(color: Self.blueNeon, radius: 3.5)
                        .opacity(paused ? 0 : 1)
                    // 流动高光（能量在跑的感觉）
                    shimmer(width: geo.size.width)
                }
                .frame(width: width)
                .shadow(color: Self.blueNeon.opacity(0.8), radius: 3)
            }
            .frame(height: 3.5)
            .opacity(paused ? 0.35 : 1)
            .animation(.linear(duration: 0.5), value: progress)
        }
    }

    private func shimmer(width: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.55), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: 28)
            .offset(x: shimmerOn ? width : -28)
            .opacity(paused ? 0 : 1)
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    shimmerOn = true
                }
            }
    }
}

/// 站立提醒横幅
private struct ReminderBanner: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(spacing: 12) {
            Text("🧍 该站起来活动一下了")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            HStack(spacing: 14) {
                Button("我站起来了") { app.acknowledge() }
                    .buttonStyle(PillButtonStyle(tint: Color.green.opacity(0.85), text: .black))
                Button("稍后 5 分钟") { app.snooze() }
                    .buttonStyle(PillButtonStyle(tint: Color.white.opacity(0.14), text: .white))
            }
        }
        .padding(.top, 38)
        .padding(.bottom, 18)
    }
}

/// 设置面板：预设 + 自定义，附带暂停与自启动
private struct SettingsPanel: View {
    @ObservedObject var app: AppState

    private let presets: [Double] = [20, 30, 45, 60]

    var body: some View {
        VStack(spacing: 12) {
            Text("提醒间隔")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { minutes in
                    Button("\(Int(minutes)) 分") { app.setInterval(minutes: minutes) }
                        .buttonStyle(
                            PillButtonStyle(
                                tint: minutes == app.intervalMinutes
                                    ? Color.accentColor
                                    : Color.white.opacity(0.14),
                                text: .white
                            )
                        )
                }
            }

            HStack(spacing: 14) {
                Button {
                    app.setInterval(minutes: app.intervalMinutes - 5)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white)

                Text("\(Int(app.intervalMinutes)) 分钟")
                    .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .frame(minWidth: 60)

                Button {
                    app.setInterval(minutes: app.intervalMinutes + 5)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white)
            }

            Divider().overlay(Color.white.opacity(0.12))

            HStack(spacing: 10) {
                Button(app.engineState == .paused ? "继续" : "暂停") { app.togglePause() }
                    .buttonStyle(PillButtonStyle(tint: Color.white.opacity(0.14), text: .white))
                Button("开机自启动：\(app.launchAtLogin ? "开" : "关")") { app.toggleLaunchAtLogin() }
                    .buttonStyle(PillButtonStyle(tint: Color.white.opacity(0.14), text: .white))
                Button("完成") { app.toggleSettings() }
                    .buttonStyle(PillButtonStyle(tint: Color.accentColor, text: .white))
            }
        }
        .padding(.top, 38)
        .padding(.bottom, 18)
    }
}

private struct PillButtonStyle: ButtonStyle {
    var tint: Color
    var text: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(text)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension TimeInterval {
    /// 倒计时显示：mm:ss（≥1 小时为 h:mm:ss）
    var clockString: String {
        let total = Int(max(0, self.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}

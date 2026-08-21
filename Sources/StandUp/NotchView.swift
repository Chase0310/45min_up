import SwiftUI

struct NotchView: View {
    @ObservedObject var app: AppState

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.4, dampingFraction: 0.65), value: app.panelMode)
    }

    @ViewBuilder
    private var content: some View {
        switch app.panelMode {
        case .compact:
            // 紧凑模式无容器背景
            CompactCountdown(app: app)
                .transition(.opacity)
        case .reminder:
            ReminderBanner(app: app)
                .background(NotchShape().fill(Color.black.opacity(0.98)))
                .transition(.scale(scale: 0.7).combined(with: .opacity))
        case .settings:
            SettingsPanel(app: app)
                .background(NotchShape().fill(Color.black.opacity(0.98)))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
        }
    }
}

/// 上边直角、底部一整条碗形大圆弧的形（顶部与屏幕顶端齐平，碗底托住内容）
private struct NotchShape: Shape {
    /// 弧的深度：两侧起点离底边的高度
    var lift: CGFloat = 32

    func path(in rect: CGRect) -> Path {
        let lift = min(lift, rect.height / 2)
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: h - lift))
        // 二次曲线：控制点在底边之下 lift 处，使中心恰好触底，形成平滑碗弧
        path.addQuadCurve(
            to: CGPoint(x: 0, y: h - lift),
            control: CGPoint(x: w / 2, y: h + lift)
        )
        path.closeSubpath()
        return path
    }
}

/// 紧凑模式：刘海下方一条与刘海同宽的普通直线倒计时；
/// 悬停时下方浮现数字
private struct CompactCountdown: View {
    @ObservedObject var app: AppState

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            VStack(spacing: 0) {
                FuseBowl(
                    progress: app.isOnBreak ? app.breakFraction : app.progressFraction,
                    paused: app.engineState == .paused,
                    accent: app.isOnBreak ? Color(red: 0.19, green: 0.82, blue: 0.35) : app.chinColor
                )
                .frame(height: 6)

                if app.hovered {
                    Group {
                        if app.isOnBreak {
                            Text("🧍 \(app.engine.breakRemaining.clockString)")
                        } else if app.engineState == .paused {
                            Text("⏸ \(app.remaining.clockString)")
                        } else {
                            Text(app.remaining.clockString)
                        }
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.85), radius: 2.5)
                    .transition(.opacity)
                }
            }
            // padding 定位：刘海开孔高度 + 间隙——macOS 26 在开孔正下方有系统级
            // 遮挡带（实测逻辑 y≈33-44+），碗必须落在带之下才真实可见
            .padding(.top, app.notchHeight + CGFloat(app.notchGap))
            .animation(.easeOut(duration: 0.18), value: app.hovered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { app.toggleSettings() }
        .onHover { app.setHover($0) }
    }
}

/// 倒计时线：一条普通直线。灰线满量程，彩线居中、两端向中间缩，
/// 无任何形状花样与循环动画——视觉白噪音
private struct FuseBowl: View {
    var progress: Double
    var paused: Bool
    var accent: Color

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width * min(max(progress, 0.04), 1), 6)
            ZStack {
                // 满量程：填充的体育场条（不是描轮廓）
                Capsule().fill(Color(white: 0.55).opacity(0.4))
                // 亮段：居中的一段，从两端向中间缩
                Capsule()
                    .fill(accent.opacity(paused ? 0.35 : 0.9))
                    .frame(width: width)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 0.8)
        .animation(.linear(duration: 0.5), value: progress)
        .animation(.easeInOut(duration: 0.2), value: paused)
    }
}

/// 站立提醒横幅：SF Symbol 官方 pulse 动效 + Apple Watch 风格文案，动效交给系统曲线
private struct ReminderBanner: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "figure.run")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)
                VStack(alignment: .leading, spacing: 2) {
                    Text("该站起来活动一下了")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("你已经坐了 \(Int(app.engine.interval / 60)) 分钟，站 \(Int(app.breakMinutes)) 分钟")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            HStack(spacing: 14) {
                Button("我站起来了") { app.acknowledge() }
                    .buttonStyle(PillButtonStyle(tint: Color.green.opacity(0.85), text: .black))
                Button("稍后 5 分钟") { app.snooze() }
                    .buttonStyle(PillButtonStyle(tint: Color.white.opacity(0.14), text: .white))
            }
        }
        .padding(.top, 38)
        .padding(.bottom, 34)
    }
}

/// 设置面板：预设 + 自定义，附带暂停与自启动
private struct SettingsPanel: View {
    @ObservedObject var app: AppState

    private let presets: [Double] = [20, 30, 45, 60]
    private static let colorSwatches = [
        "#008CFF", // 钻蓝（默认）
        "#00E5FF", // 电光青
        "#30D158", // 苹果绿
        "#FF9F0A", // 琥珀
        "#FF375F", // 霓虹粉
        "#FFFFFF", // 白
    ]

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

            HStack {
                Text("站立时长")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Button {
                    app.breakMinutes -= 1
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white)
                Text("\(Int(app.breakMinutes)) 分钟")
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .frame(minWidth: 52)
                Button {
                    app.breakMinutes += 1
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white)
            }
            .padding(.horizontal, 4)

            HStack {
                Text("线条颜色")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                // 预设色块：点击即生效，不依赖系统取色器
                HStack(spacing: 8) {
                    ForEach(Self.colorSwatches, id: \.self) { hex in
                        Button {
                            app.chinColor = Color(hex: hex)
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle().stroke(
                                        app.chinColor.hexString == hex
                                            ? Color.white : Color.white.opacity(0.25),
                                        lineWidth: app.chinColor.hexString == hex ? 2 : 1
                                    )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                ColorPicker("", selection: $app.chinColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 44)
            }
            .padding(.horizontal, 4)

            HStack {
                Text("线条位置（离刘海）")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Button {
                    app.notchGap -= 1
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white)
                Text("\(Int(app.notchGap)) pt")
                    .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .frame(minWidth: 40)
                Button {
                    app.notchGap += 1
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.white)
            }
            .padding(.horizontal, 4)

            Divider().overlay(Color.white.opacity(0.12))

            HStack(spacing: 10) {
                Button("重新计时") { app.restartRound() }
                    .buttonStyle(PillButtonStyle(tint: Color.white.opacity(0.14), text: .white))
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

extension Color {
    /// "#RRGGBB" → Color（坏字符串回落默认钻蓝）
    init(hex: String) {
        var value: UInt64 = 0
        var cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        if cleaned.count != 6 || !Scanner(string: cleaned).scanHexInt64(&value) {
            cleaned = String(SettingsStore.defaultAccentHex.dropFirst())
            Scanner(string: cleaned).scanHexInt64(&value)
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// Color → "#RRGGBB"
    var hexString: String {
        guard let rgb = NSColor(self).usingColorSpace(.deviceRGB) else {
            return SettingsStore.defaultAccentHex
        }
        return String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
    }

    /// 降亮度派生深色档（饱和度略提，避免发灰）
    func darkened(_ factor: Double) -> Color {
        guard let rgb = NSColor(self).usingColorSpace(.deviceRGB) else { return self }
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        return Color(
            hue: Double(hue),
            saturation: Double(min(1, saturation * 1.15)),
            brightness: Double(max(0, brightness * factor)),
            opacity: Double(alpha)
        )
    }
}

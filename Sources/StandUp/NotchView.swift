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

/// 上边直角、下边圆角的形（顶部与屏幕顶端齐平，视觉上像刘海的延伸）；半径可调
private struct NotchShape: Shape {
    var radius: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        let radius = min(radius, rect.height / 2)
        let w = rect.width
        let h = rect.height
        var path = Path()
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
        return path
    }
}

/// 紧凑模式：一条贴在刘海下缘 2pt、与刘海同宽的倒计时线，
/// 无任何容器；悬停时下方浮现带描影的数字
private struct CompactCountdown: View {
    @ObservedObject var app: AppState

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            VStack(spacing: 4) {
                FuseLine(
                    progress: app.progressFraction,
                    paused: app.engineState == .paused,
                    accent: app.chinColor,
                    urgent: app.isUrgent
                )
                .frame(height: 6)

                if app.hovered {
                    Group {
                        if app.engineState == .paused {
                            Text("⏸ \(app.remaining.clockString)")
                        } else {
                            Text(app.remaining.clockString)
                        }
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.85), radius: 2.5) // 无底色容器的可读性
                    .transition(.opacity)
                }
            }
            // padding 定位：刘海开孔高度 + 16pt 间隙——macOS 26 在开孔正下方有系统级
            // 遮挡带（实测逻辑 y≈33-44+），线必须落在带之下才真实可见
            .padding(.top, app.notchHeight + CGFloat(app.notchGap))
            .animation(.easeOut(duration: 0.18), value: app.hovered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { app.toggleSettings() }
        .onHover { app.setHover($0) }
    }
}

/// 倒计时线：6pt 圆头，亮段 = 纯色体 + 白色管芯 + 主题色辉光，
/// 两端柔光火苗呼吸脉动 + 高光能量流；最后 1 分钟进入 urgent 高潮
/// （火苗狂跳、管芯炽白偏橙、光晕加强）；从两头向中间收缩
private struct FuseLine: View {
    var progress: Double
    var paused: Bool
    var accent: Color
    var urgent: Bool

    @State private var shimmerOn = false
    @State private var flamePulse = false

    private var coreColor: Color {
        urgent ? Color(red: 1, green: 0.82, blue: 0.55) : Color.white.opacity(0.85)
    }
    private var glowColor: Color {
        urgent ? Color(red: 1, green: 0.55, blue: 0.2) : accent
    }

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width * progress, 6)
            ZStack {
                // 满量程槽：中性中灰，浅色/深色壁纸都可见
                Capsule().fill(Color(white: 0.55).opacity(0.5))
                // 亮段：居中、两边向中间烧
                ZStack {
                    Capsule().fill(accent)
                    Capsule()
                        .fill(coreColor)
                        .frame(height: 1.2) // 管芯
                        .padding(.horizontal, 3)
                    // 两端火苗
                    HStack(spacing: 0) {
                        flame
                        Spacer(minLength: 0)
                        flame
                    }
                    // 能量流
                    shimmer(width: geo.size.width)
                }
                .frame(width: width)
                .shadow(color: glowColor.opacity(urgent ? 1 : 0.8), radius: urgent ? 5 : 3)
                .opacity(paused ? 0.35 : 1)
            }
            .shadow(color: .black.opacity(0.4), radius: 1) // 浅壁纸上切出轮廓
        }
        .animation(.linear(duration: 0.5), value: progress)
        .animation(.easeInOut(duration: 0.2), value: paused)
    }

    /// 端点火苗：柔光径向渐变，呼吸脉动（urgent 时倍速狂跳）
    private var flame: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [coreColor, glowColor.opacity(0.55), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 5.5
                )
            )
            .frame(width: 11, height: 11)
            .scaleEffect(flamePulse ? 1.3 : 0.8)
            .opacity(paused ? 0 : (flamePulse ? 0.6 : 1))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: urgent ? 0.4 : 0.9)
                        .repeatForever(autoreverses: true)
                ) {
                    flamePulse = true
                }
            }
    }

    /// 高光能量流：一段白光周期性从线头扫到线尾
    private func shimmer(width: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(urgent ? 0.7 : 0.45), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: min(26, width))
            .offset(x: shimmerOn ? width : -26)
            .opacity(paused ? 0 : 1)
            .onAppear {
                withAnimation(
                    .linear(duration: urgent ? 0.8 : 1.6)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerOn = true
                }
            }
    }
}

/// 站立提醒横幅：原地蹦跳的小人 + 呼吸脉动的主按钮 + 顶部会师火花辉光
private struct ReminderBanner: View {
    @ObservedObject var app: AppState

    @State private var buttonBreath = false
    @State private var sparkPulse = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text("🧍")
                    .font(.system(size: 24))
                    .modifier(HopInPlace())
                Text("该站起来活动一下了")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            HStack(spacing: 14) {
                Button("我站起来了") { app.acknowledge() }
                    .buttonStyle(PillButtonStyle(tint: Color.green.opacity(0.85), text: .black))
                    .scaleEffect(buttonBreath ? 1.06 : 1)
                Button("稍后 5 分钟") { app.snooze() }
                    .buttonStyle(PillButtonStyle(tint: Color.white.opacity(0.14), text: .white))
            }
        }
        .padding(.top, 38)
        .padding(.bottom, 18)
        // 顶部交汇点残余火花：两团火在此会师，留一团脉动辉光（不越窗口边界）
        .overlay(alignment: .top) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [app.chinColor.opacity(0.9), app.chinColor.opacity(0.25), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 26
                    )
                )
                .frame(width: 52, height: 52)
                .offset(y: 24)
                .scaleEffect(sparkPulse ? 1.25 : 0.7)
                .opacity(sparkPulse ? 0.35 : 0.95)
                .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                buttonBreath = true
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                sparkPulse = true
            }
        }
    }
}

/// 原地小跳：起跳 + 轻微左右倾，循环
private struct HopInPlace: ViewModifier {
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -5 : 0)
            .rotationEffect(.degrees(up ? -7 : 5))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
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

            HStack {
                Text("线条颜色")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                ColorPicker("", selection: $app.chinColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 56)
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

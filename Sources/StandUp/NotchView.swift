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

/// 紧凑模式：挂在刘海下方的"碗"——一条与刘海同宽的 ∪ 弧倒计时，
/// 进度沿弧从两端向碗底烧；悬停时数字浮现在碗的凹腔里
private struct CompactCountdown: View {
    @ObservedObject var app: AppState

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            VStack(spacing: 0) {
                FuseBowl(
                    progress: app.progressFraction,
                    paused: app.engineState == .paused,
                    accent: app.chinColor,
                    urgent: app.isUrgent
                )
                .frame(height: 22)

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

/// 碗形保险丝：与刘海同宽的 ∪ 弧，6pt 圆头描边——灰弧为满量程，
/// 亮弧居中、从两端向碗底烧；白管芯、端点火苗脉动、能量点沿弧巡回；urgent 加热
private struct FuseBowl: View {
    var progress: Double
    var paused: Bool
    var accent: Color
    var urgent: Bool

    @State private var flamePulse = false

    private var coreColor: Color {
        urgent ? Color(red: 1, green: 0.82, blue: 0.55) : Color.white.opacity(0.85)
    }
    private var glowColor: Color {
        urgent ? Color(red: 1, green: 0.55, blue: 0.2) : accent
    }

    /// 亮弧参数区间（弧参数 0=左端 1=右端，0.5=碗底）
    private var litRange: ClosedRange<Double> {
        let p = min(max(progress, 0.04), 1)
        return (1 - p) / 2 ... (1 + p) / 2
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let depth = geo.size.height - 6 // 弧线本身占 6pt
            let scale = depth / (w / 2)
            let arc = BowlArc(depthScale: min(1, max(0.05, scale)))
            let stroke = StrokeStyle(lineWidth: 6, lineCap: .round)

            ZStack {
                // 满量程弧：中性中灰
                arc.stroke(Color(white: 0.55).opacity(0.5), style: stroke)
                    .shadow(color: .black.opacity(0.4), radius: 1)

                // 亮弧 + 管芯 + 辉光
                arc.trim(from: litRange.lowerBound, to: litRange.upperBound)
                    .stroke(accent, style: stroke)
                    .shadow(color: glowColor.opacity(urgent ? 1 : 0.8), radius: urgent ? 5 : 3)
                arc.trim(from: litRange.lowerBound, to: litRange.upperBound)
                    .stroke(coreColor, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .opacity(paused ? 0.35 : 1)

                // 端点火苗（亮弧两端）
                flame(at: arcPoint(litRange.lowerBound, w: w, depth: depth))
                flame(at: arcPoint(litRange.upperBound, w: w, depth: depth))

                // 能量点沿亮弧巡回
                TimelineView(.animation(minimumInterval: 0.05)) { context in
                    let period = urgent ? 0.8 : 1.6
                    let t = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: period) / period
                    let param = litRange.lowerBound + t * (litRange.upperBound - litRange.lowerBound)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 3.5, height: 3.5)
                        .position(arcPoint(param, w: w, depth: depth))
                        .opacity(paused ? 0 : 0.9)
                }
            }
        }
        .opacity(paused ? 0.6 : 1)
        .animation(.linear(duration: 0.5), value: progress)
        .animation(.easeInOut(duration: 0.2), value: paused)
    }

    /// 弧参数 t∈[0,1] → 几何坐标（0=左端，0.5=碗底，1=右端）
    private func arcPoint(_ t: Double, w: CGFloat, depth: CGFloat) -> CGPoint {
        let angle = (180 - t * 180) * .pi / 180
        let r = w / 2
        return CGPoint(
            x: r + r * CGFloat(cos(angle)),
            y: 3 + depth * CGFloat(sin(angle)) // 3pt 补偿描边半径，让火苗贴在弧线上
        )
    }

    private func flame(at point: CGPoint) -> some View {
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
            .position(point)
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
}

/// 单位碗弧：以 (w/2, 0) 为圆心的下半圆，再纵向压扁到目标深度
private struct BowlArc: Shape {
    var depthScale: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        var p = Path()
        p.addArc(
            center: CGPoint(x: r, y: 0),
            radius: r,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: true
        )
        return p.applying(CGAffineTransform(scaleX: 1, y: depthScale))
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
                    Text("你已经坐了 \(Int(app.engine.interval / 60)) 分钟")
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

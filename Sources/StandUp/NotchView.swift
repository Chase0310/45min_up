import SwiftUI

struct NotchView: View {
    @ObservedObject var app: AppState

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: app.panelMode)
    }

    @ViewBuilder
    private var content: some View {
        switch app.panelMode {
        case .compact:
            // 紧凑模式自带蓝色胶囊背景，不用黑色 NotchShape
            CompactCountdown(app: app)
        case .reminder:
            ReminderBanner(app: app).background(NotchShape())
        case .settings:
            SettingsPanel(app: app).background(NotchShape())
        }
    }
}

/// 上边直角、下边圆角的底（顶部与屏幕顶端齐平，视觉上像刘海的延伸）；半径可调
private struct NotchShape: View {
    var radius: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let radius = min(radius, geo.size.height / 2)
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

/// 紧凑模式：黑色"岛"与刘海底缘无缝相接（Dynamic Island 纪律：像刘海自己长出来的），
/// 岛内嵌彩色保险丝，悬停岛体长高、白字浮现在黑岛里
private struct CompactCountdown: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: app.notchHeight) // 开孔区（无像素）
            CompactIsland(
                progress: app.progressFraction,
                paused: app.engineState == .paused,
                hovered: app.hovered,
                accent: app.chinColor,
                text: app.engineState == .paused
                    ? "⏸ \(app.remaining.clockString)" : app.remaining.clockString
            )
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .contentShape(Rectangle())
        .onTapGesture { app.toggleSettings() }
        .onHover { app.setHover($0) }
    }
}

/// 黑色岛体：顶部齐屏隐入开孔、底部圆角，纯黑壳保证与任何壁纸（含蓝壁纸）都有对比
private struct CompactIsland: View {
    var progress: Double
    var paused: Bool
    var hovered: Bool
    var accent: Color
    var text: String

    var body: some View {
        VStack(spacing: 4) {
            FuseLine(progress: progress, paused: paused, accent: accent)
                .frame(height: 4)
                .padding(.horizontal, 12)
                .padding(.top, 5)
            Text(text)
                .font(.system(size: 13, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .opacity(hovered ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            NotchShape(radius: hovered ? 16 : 12)
                .fill(Color.black.opacity(0.92))
        )
        .animation(.easeOut(duration: 0.18), value: hovered)
    }
}

/// 保险丝：中性暗槽 + 彩色亮段居中、两边向中间烧，白热燃点 + 流光
private struct FuseLine: View {
    var progress: Double
    var paused: Bool
    var accent: Color

    @State private var shimmerOn = false

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width * progress, 6)
            ZStack {
                // 暗槽：白 12%（黑岛内的中性满量程参照，不随取色变化）
                Capsule().fill(Color.white.opacity(0.12))
                // 亮段：居中、两边向中间收缩
                ZStack {
                    Capsule().fill(
                        LinearGradient(
                            colors: [accent, accent.darkened(0.7), accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    HStack(spacing: 0) {
                        BurnTip(color: accent, paused: paused)
                        Spacer(minLength: 0)
                        BurnTip(color: accent, paused: paused)
                    }
                    shimmer(width: geo.size.width)
                }
                .frame(width: width)
                .shadow(color: accent.opacity(0.9), radius: 3)
                .opacity(paused ? 0.35 : 1)
            }
        }
        .animation(.linear(duration: 0.5), value: progress)
    }

    private func shimmer(width: CGFloat) -> some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.5), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: min(24, width))
            .offset(x: shimmerOn ? width : -24)
            .opacity(paused ? 0 : 1)
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    shimmerOn = true
                }
            }
    }
}

/// 燃烧面：白热核心 + 基础色光晕呼吸脉动
private struct BurnTip: View {
    var color: Color
    var paused: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.55))
                .frame(width: 12, height: 12)
                .scaleEffect(pulse ? 1.4 : 0.75)
                .opacity(pulse ? 0.05 : 0.8)
            Circle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
        }
        .shadow(color: color, radius: 5)
        .opacity(paused ? 0 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulse = true
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

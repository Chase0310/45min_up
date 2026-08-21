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
            ReminderBanner(app: app).background(NotchShape().fill(Color.black.opacity(0.98)))
        case .settings:
            SettingsPanel(app: app).background(NotchShape().fill(Color.black.opacity(0.98)))
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

/// 紧凑模式：只有一条发丝线——贴在刘海下缘 3pt、与刘海同宽（boring.notch 收起态纪律），
/// 无任何容器；悬停时下方浮现带描影的数字
private struct CompactCountdown: View {
    @ObservedObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: app.notchHeight + 3) // 开孔区（无像素）+ 与刘海的间隙
            VStack(spacing: 4) {
                FuseLine(
                    progress: app.progressFraction,
                    paused: app.engineState == .paused,
                    accent: app.chinColor
                )
                .frame(height: 2.5)

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
                .opacity(app.hovered ? 1 : 0)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.easeOut(duration: 0.18), value: app.hovered)
        }
        .contentShape(Rectangle())
        .onTapGesture { app.toggleSettings() }
        .onHover { app.setHover($0) }
    }
}

/// 发丝保险丝：2.5pt 圆头细线、纯色、零光晕零流光（克制即高级），
/// 唯一特效 = 亮段从两头向中间收缩；中性灰槽在明暗壁纸都成立
private struct FuseLine: View {
    var progress: Double
    var paused: Bool
    var accent: Color

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width * progress, 4)
            ZStack {
                // 满量程槽：中性中灰，浅色/深色壁纸都可见
                Capsule().fill(Color(white: 0.55).opacity(0.45))
                // 亮段：居中、两边向中间烧
                Capsule()
                    .fill(accent)
                    .frame(width: width)
                    .opacity(paused ? 0.35 : 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 0.8) // 浅壁纸上切出轮廓
        }
        .animation(.linear(duration: 0.5), value: progress)
        .animation(.easeInOut(duration: 0.2), value: paused)
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

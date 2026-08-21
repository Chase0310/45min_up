import Foundation

/// 用户设置的持久化（间隔分钟数）。数值合法性在读取时收敛，坏值回落默认 45。
struct SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var intervalMinutes: Double {
        get {
            let v = defaults.double(forKey: Keys.interval)
            return (5...240).contains(v) ? v : 45
        }
        set { defaults.set(newValue, forKey: Keys.interval) }
    }

    /// 线条基础色（#RRGGBB），燃点/光晕/深色档由此派生
    var accentHex: String {
        get {
            let v = defaults.string(forKey: Keys.accent) ?? ""
            return v.count == 7 ? v : Self.defaultAccentHex
        }
        set { defaults.set(newValue, forKey: Keys.accent) }
    }

    /// 线条与刘海底缘的间隙（pt）。macOS 26 开孔正下方有系统遮挡带（实测到 ~12pt），
    /// 默认 13 刚好出带；用户可按自己屏幕观感微调
    var notchGap: Double {
        get {
            let v = defaults.double(forKey: Keys.gap)
            return (6...30).contains(v) ? v : 13
        }
        set { defaults.set(min(30, max(6, newValue)), forKey: Keys.gap) }
    }

    static let defaultAccentHex = "#008CFF"

    private enum Keys {
        static let interval = "com.chase0310.45minup.interval"
        static let accent = "com.chase0310.45minup.accent"
        static let gap = "com.chase0310.45minup.gap"
    }
}

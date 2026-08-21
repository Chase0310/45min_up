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

    private enum Keys {
        static let interval = "com.chase0310.45minup.interval"
    }
}

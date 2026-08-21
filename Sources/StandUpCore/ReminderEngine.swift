import Foundation

/// 站立提醒的计时状态机（术语见 CONTEXT.md）。
/// 纯值类型 + 注入时钟：所有时间推进都经由 `advance(to:)` 显式驱动。
public struct ReminderEngine {
    public enum State: Equatable {
        case counting
        case reminding
        case paused
    }

    /// 交给外壳层响应的离散事件（提示音/系统通知只在事件发生时触发一次）
    public enum Event: Equatable {
        case reminderStarted
    }

    private var lastTick: Date

    public private(set) var interval: TimeInterval
    public private(set) var remaining: TimeInterval
    public private(set) var state: State = .counting

    public init(interval: TimeInterval, now: Date) {
        self.interval = interval
        self.remaining = interval
        self.lastTick = now
    }

    /// 推进到 `now`。仅 counting 状态消耗剩余时间；时钟回拨（delta<0）忽略。
    @discardableResult
    public mutating func advance(to now: Date) -> [Event] {
        let delta = now.timeIntervalSince(lastTick)
        lastTick = now
        guard delta > 0, state == .counting else { return [] }
        remaining -= delta
        if remaining <= 0 {
            remaining = 0
            state = .reminding
            return [.reminderStarted]
        }
        return []
    }

    /// 确认（我站起来了）：宣告本轮久坐结束，倒计时按间隔重新起算
    public mutating func acknowledge(now: Date) {
        guard state == .reminding else { return }
        remaining = interval
        state = .counting
        lastTick = now
    }

    /// 稍后：推迟 `delay`（默认 5 分钟）再次提醒
    public mutating func snooze(now: Date, delay: TimeInterval = 5 * 60) {
        guard state == .reminding else { return }
        remaining = delay
        state = .counting
        lastTick = now
    }

    /// 暂停：冻结倒计时（系统睡眠或手动会议模式）。仅在 counting 态生效，返回是否真的暂停了。
    @discardableResult
    public mutating func pause(now: Date) -> Bool {
        guard state == .counting else { return false }
        state = .paused
        lastTick = now
        return true
    }

    /// 恢复：从冻结处继续
    public mutating func resume(now: Date) {
        guard state == .paused else { return }
        state = .counting
        lastTick = now
    }

    /// 调整间隔：当前轮按新间隔从头起算
    public mutating func setInterval(_ newInterval: TimeInterval, now: Date) {
        interval = newInterval
        remaining = newInterval
        state = .counting
        lastTick = now
    }
}

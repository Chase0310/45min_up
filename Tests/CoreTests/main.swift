import StandUpCore
import Foundation

// 微测试壳：swift run CoreTests。✘ 任一即退出码 1（红）。
var total = 0
var failed = 0

func it(_ name: String, _ body: () throws -> Void) {
    total += 1
    do {
        try body()
        print("✔ \(name)")
    } catch {
        failed += 1
        print("✘ \(name)\n    \(error)")
    }
}

struct ExpectationFailed: Error, CustomStringConvertible {
    let description: String
}

func expect(_ condition: Bool, _ message: String) throws {
    if !condition { throw ExpectationFailed(description: message) }
}

let t0 = Date(timeIntervalSince1970: 1_000_000)
let minute: TimeInterval = 60

// Cycle 1: 引擎启动即处于完整间隔的倒计时状态
it("启动时进入完整间隔倒计时") {
    let engine = ReminderEngine(interval: 45 * minute, now: t0)
    try expect(engine.remaining == 45 * minute, "remaining 应为完整间隔，实际 \(engine.remaining)")
    try expect(engine.state == .counting, "初始状态应为 counting，实际 \(engine.state)")
}

// Cycle 2: advance 按流逝时间消耗倒计时
it("advance 消耗流逝的时间") {
    var engine = ReminderEngine(interval: 45 * minute, now: t0)
    _ = engine.advance(to: t0.addingTimeInterval(60))
    try expect(engine.remaining == 44 * minute, "60 秒后应剩 44 分钟，实际 \(engine.remaining)")
}

// Cycle 3: 归零进入提醒态，reminderStarted 只发一次
it("归零进入提醒态且事件只发一次") {
    var engine = ReminderEngine(interval: minute, now: t0)
    var events = engine.advance(to: t0.addingTimeInterval(minute))
    try expect(engine.state == .reminding, "归零后应为 reminding，实际 \(engine.state)")
    try expect(events == [.reminderStarted], "应恰好发出一次 reminderStarted，实际 \(events)")
    events = engine.advance(to: t0.addingTimeInterval(minute + 10))
    try expect(events.isEmpty, "提醒态继续 advance 不应再发事件，实际 \(events)")
}

// Cycle 4: 确认（我站起来了）→ 从完整间隔重新起算
it("确认后倒计时归整重来") {
    var engine = ReminderEngine(interval: 45 * minute, now: t0)
    _ = engine.advance(to: t0.addingTimeInterval(45 * minute))
    engine.acknowledge(now: t0.addingTimeInterval(45 * minute + 5))
    try expect(engine.state == .counting, "确认后应回到 counting，实际 \(engine.state)")
    try expect(engine.remaining == 45 * minute, "确认后应恢复完整间隔，实际 \(engine.remaining)")
}

// Cycle 5: 稍后 = 推迟 5 分钟再次提醒
it("稍后5分钟再次提醒") {
    var engine = ReminderEngine(interval: minute, now: t0)
    _ = engine.advance(to: t0.addingTimeInterval(minute))
    engine.snooze(now: t0.addingTimeInterval(minute))
    try expect(engine.state == .counting, "稍后后应回到 counting，实际 \(engine.state)")
    try expect(engine.remaining == 5 * minute, "稍后应剩 5 分钟，实际 \(engine.remaining)")
    var events = engine.advance(to: t0.addingTimeInterval(minute + 5 * minute))
    try expect(events == [.reminderStarted], "5 分钟后应再次提醒，实际 \(events)")
}

// Cycle 6: 暂停冻结倒计时，恢复后继续（不丢进度）
it("暂停冻结恢复继续") {
    var engine = ReminderEngine(interval: 10 * minute, now: t0)
    _ = engine.advance(to: t0.addingTimeInterval(4 * minute))
    engine.pause(now: t0.addingTimeInterval(4 * minute))
    _ = engine.advance(to: t0.addingTimeInterval(4 * minute + 60 * minute)) // 暂停中过 1 小时
    try expect(engine.state == .paused, "暂停后应为 paused，实际 \(engine.state)")
    try expect(engine.remaining == 6 * minute, "暂停中不消耗，应仍剩 6 分钟，实际 \(engine.remaining)")
    engine.resume(now: t0.addingTimeInterval(4 * minute + 60 * minute))
    _ = engine.advance(to: t0.addingTimeInterval(4 * minute + 60 * minute + minute))
    try expect(engine.state == .counting, "恢复后应 counting，实际 \(engine.state)")
    try expect(engine.remaining == 5 * minute, "恢复后继续消耗，应剩 5 分钟，实际 \(engine.remaining)")
}

// Cycle 7: 调整间隔 → 当前轮按新间隔从头起算
it("调整间隔后整轮重置") {
    var engine = ReminderEngine(interval: 45 * minute, now: t0)
    _ = engine.advance(to: t0.addingTimeInterval(10 * minute))
    engine.setInterval(20 * minute, now: t0.addingTimeInterval(10 * minute))
    try expect(engine.interval == 20 * minute, "间隔应更新为 20 分钟")
    try expect(engine.remaining == 20 * minute, "改间隔应整轮重置，实际剩 \(engine.remaining)")
    try expect(engine.state == .counting, "改间隔后应 counting，实际 \(engine.state)")
}

// Cycle 8: 时钟回拨（睡眠唤醒边缘/手动改钟）不产生负消耗
it("时钟回拨被忽略") {
    var engine = ReminderEngine(interval: 10 * minute, now: t0)
    _ = engine.advance(to: t0.addingTimeInterval(minute))
    _ = engine.advance(to: t0.addingTimeInterval(-30)) // 回拨 30 秒
    try expect(engine.remaining == 9 * minute, "回拨不应改变剩余，应仍剩 9 分钟，实际 \(engine.remaining)")
}

// Cycle 9: 点击与当前相同的间隔 = 立即整轮重来（免得用户被迫切走再切回）
it("点击当前间隔立即整轮重来") {
    var engine = ReminderEngine(interval: 30 * minute, now: t0)
    _ = engine.advance(to: t0.addingTimeInterval(15 * minute))
    engine.setInterval(30 * minute, now: t0.addingTimeInterval(15 * minute)) // 同值重设
    try expect(engine.remaining == 30 * minute, "同值重设应立即回到满间隔，实际剩 \(engine.remaining)")
    try expect(engine.state == .counting, "同值重设后应 counting，实际 \(engine.state)")
}

print("\n\(total - failed)/\(total) 通过")
if failed > 0 { exit(1) }

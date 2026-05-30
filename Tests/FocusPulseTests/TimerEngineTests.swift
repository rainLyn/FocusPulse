import Testing
import Foundation
@testable import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  TimerEngine — 状态机测试
// ═════════════════════════════════════════════════════════════
struct TimerEngineTests {

    @Test("初始 idle，elapsed 为 0")
    func initialState() {
        let engine = TimerEngine()
        #expect(engine.state == .idle)
        #expect(engine.elapsedSeconds == 0)
        #expect(!engine.isRunning)
    }

    @Test("start → running，end 后 → ended")
    func lifeCycle() {
        let engine = TimerEngine()
        let catId = UUID()
        engine.start(categoryId: catId)

        #expect(engine.isRunning)
        #expect(engine.elapsedSeconds == 0)

        // 给 Timer 一个 tick 的机会
        Thread.sleep(forTimeInterval: 0.15)

        engine.stop()

        #expect(engine.state == .ended(FocusSession(categoryId: catId)))

        if case .ended(let session) = engine.state {
            #expect(session.categoryId == catId)
            #expect(session.endTime != nil)
            #expect(session.durationSeconds > 0)
        }
    }

    @Test("running 时重复 start 不生效")
    func doubleStartNoop() {
        let engine = TimerEngine()
        engine.start(categoryId: UUID())
        // 保存当前引用
        let ref = engine.state
        engine.start(categoryId: UUID()) // 第二次应被忽略
        // 状态不变
        if case .running(let since) = engine.state, case .running(let refSince) = ref {
            #expect(since == refSince)
        }
    }

    @Test("idle 时 stop 不改变状态")
    func stopOnIdle() {
        let engine = TimerEngine()
        engine.stop()
        #expect(engine.state == .idle)
    }

    @Test("reset 回到 idle")
    func reset() {
        let engine = TimerEngine()
        engine.start(categoryId: UUID())
        engine.stop()
        engine.reset()
        #expect(engine.state == .idle)
        #expect(engine.elapsedSeconds == 0)
    }

    @Test("restore 从 5 分钟前的 session 恢复 elapsed=300+")
    func restore() {
        let engine = TimerEngine()
        let catId = UUID()
        let start = Date().addingTimeInterval(-300)
        let session = FocusSession(
            categoryId: catId,
            startTime: start,
            endTime: nil,
            durationSeconds: 0
        )
        engine.restore(session: session, currentTime: Date())
        #expect(engine.isRunning)
        #expect(engine.elapsedSeconds >= 300)
    }

    @Test("computeElapsed 在 running 时返回实时值")
    func computeElapsedInRunning() {
        let engine = TimerEngine()
        engine.start(categoryId: UUID())
        #expect(engine.computeElapsed() >= 0)
        engine.stop()
    }

    @Test("stop 后 elapsed 冻结")
    func elapsedFrozenAfterStop() {
        let engine = TimerEngine()
        engine.start(categoryId: UUID())
        Thread.sleep(forTimeInterval: 0.1)
        engine.stop()
        let frozen = engine.elapsedSeconds
        Thread.sleep(forTimeInterval: 0.1)
        #expect(engine.computeElapsed() == frozen)
    }
}

// ═════════════════════════════════════════════════════════════
//  StreakCalculator — 连续天数计算
// ═════════════════════════════════════════════════════════════
struct StreakCalculatorTests {
    let cal = Calendar.current

    @Test("空数据 → 0")
    func empty() {
        #expect(StreakCalculator.longestStreak(from: [:]) == 0)
    }

    @Test("连续 5 天 → 5")
    func fiveDays() {
        let heatmap = days(0..<5, offset: 3600)
        #expect(StreakCalculator.longestStreak(from: heatmap) == 5)
    }

    @Test("跳跃天数打断连续")
    func gapBreaks() {
        var heatmap = days(0..<2, offset: 3600)    // 今天 + 昨天
        heatmap.merge(days(-5..<(-2), offset: 3600)) { $1 } // 3 天连续（久远）
        #expect(StreakCalculator.longestStreak(from: heatmap) == 3)
    }

    @Test("两个连续段取最长")
    func pickLongest() {
        var heatmap = days(-7..<(-3), offset: 3600)   // 4 天
        heatmap.merge(days(-2..<0, offset: 3600)) { $1 }  // 2 天
        #expect(StreakCalculator.longestStreak(from: heatmap) == 4)
    }

    @Test("currentStreak 从今天开始往回数")
    func currentStreak() {
        let heatmap = days(-4..<1, offset: 3600) // 今天 + 往回 4 天
        #expect(StreakCalculator.currentStreak(from: heatmap) == 5)
    }

    @Test("今天无记录 → currentStreak = 0")
    func noRecordTodayCurrent() {
        let heatmap = days(-5..<0, offset: 3600) // 没有今天
        #expect(StreakCalculator.currentStreak(from: heatmap) == 0)
    }

    // 构造 [date: seconds] 辅助
    private func days(_ range: Range<Int>, offset: Int) -> [Date: Int] {
        let today = Date()
        var result: [Date: Int] = [:]
        for d in range {
            let date = cal.startOfDay(for: cal.date(byAdding: .day, value: d, to: today)!)
            result[date] = offset
        }
        return result
    }
}

// ═════════════════════════════════════════════════════════════
//  Formatting — 时间格式化
// ═════════════════════════════════════════════════════════════
struct FormattingTests {

    @Test("prettyFormat: 边界值")
    func prettyBoundary() {
        #expect(0.prettyFormat == "<1m")
        #expect(59.prettyFormat == "<1m")
        #expect(60.prettyFormat == "1m")
        #expect(3540.prettyFormat == "59m")
        #expect(3600.prettyFormat == "1h 0m")
        #expect(3661.prettyFormat == "1h 1m")
    }

    @Test("hmsFormat: 边界值")
    func hmsBoundary() {
        #expect(0.hmsFormat == "00:00:00")
        #expect(3661.hmsFormat == "01:01:01")
        #expect(86399.hmsFormat == "23:59:59")
    }

    @Test("timeRange 包含连字符")
    func timeRangeHasDash() {
        let start = Date()
        let range = start.timeRange(to: start.addingTimeInterval(3600))
        #expect(range.contains("-"))
    }
}


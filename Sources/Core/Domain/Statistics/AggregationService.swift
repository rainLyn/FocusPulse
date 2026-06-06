import Foundation

// ═════════════════════════════════════════════════════════════
//  AggregationService — 聚合计算服务
//  专注时长汇总、趋势分析、Heatmap 数据准备
// ═════════════════════════════════════════════════════════════
@MainActor
public final class AggregationService {
    private let sessionRepo: SessionRepository
    private let summaryRepo: SummaryRepository
    private let categoryRepo: CategoryRepository

    public init(
        sessionRepo: SessionRepository? = nil,
        summaryRepo: SummaryRepository? = nil,
        categoryRepo: CategoryRepository? = nil
    ) {
        self.sessionRepo = sessionRepo ?? SessionRepository()
        self.summaryRepo = summaryRepo ?? SummaryRepository()
        self.categoryRepo = categoryRepo ?? CategoryRepository()
    }

    // ──────────────────────────────────────────────
    //  日统计
    // ──────────────────────────────────────────────
    public struct DailyBreakdown {
        public let totalSeconds: Int
        public let items: [CategoryBreakdown]
    }

    public struct CategoryBreakdown: Identifiable {
        public let id: UUID
        public let categoryId: UUID
        public let categoryName: String
        public let colorHex: String
        public let seconds: Int
        public let percentage: Double
        public let sessionCount: Int
    }

    public func dailyBreakdown(for date: Date) -> DailyBreakdown {
        let summaries = summaryRepo.summary(for: date)
        let cats = categoryRepo.fetchAll(includeArchived: true)
        let catMap = Dictionary(uniqueKeysWithValues: cats.map { ($0.id, $0) })

        let items: [CategoryBreakdown] = summaries.compactMap { s in
            guard let cat = catMap[s.categoryId] else { return nil }
            return CategoryBreakdown(
                id: s.id,
                categoryId: s.categoryId,
                categoryName: cat.name,
                colorHex: cat.colorHex,
                seconds: s.totalSeconds,
                percentage: 0.0, // 稍后计算
                sessionCount: s.sessionCount
            )
        }

        let total = items.reduce(0) { $0 + $1.seconds }
        let withPct = items.map { item in
            CategoryBreakdown(
                id: item.id,
                categoryId: item.categoryId,
                categoryName: item.categoryName,
                colorHex: item.colorHex,
                seconds: item.seconds,
                percentage: total > 0 ? Double(item.seconds) / Double(total) : 0,
                sessionCount: item.sessionCount
            )
        }

        return DailyBreakdown(totalSeconds: total, items: withPct)
    }

    /// 该日按时间排序的专注记录列表
    public func sessionTimeline(for date: Date) -> [(session: FocusSession, categoryName: String, colorHex: String)] {
        let sessions = sessionRepo.fetch(date: date).filter { $0.durationSeconds >= 30 }
        let cats = categoryRepo.fetchAll(includeArchived: true)
        let catMap = Dictionary(uniqueKeysWithValues: cats.map { ($0.id, $0) })

        return sessions.map { s in
            let cat = catMap[s.categoryId]
            return (s, cat?.name ?? "已删除", cat?.colorHex ?? "999999")
        }
    }

    // ──────────────────────────────────────────────
    //  年统计（Heatmap）
    // ──────────────────────────────────────────────
    public func yearlyHeatmap(year: Int) -> [Date: Int] {
        summaryRepo.heatmapData(year: year)
    }

    public struct YearlySummary {
        public let totalSeconds: Int
        public let longestStreak: Int
        public let averageDailySeconds: Int
    }

    public func yearlySummary(year: Int) -> YearlySummary {
        let heatmap = yearlyHeatmap(year: year)
        let total = heatmap.values.reduce(0, +)
        let daysCount = heatmap.keys.count
        let streak = StreakCalculator.longestStreak(from: heatmap)
        return YearlySummary(
            totalSeconds: total,
            longestStreak: streak,
            averageDailySeconds: daysCount > 0 ? total / max(daysCount, 1) : 0
        )
    }

    /// 按月统计每天的总专注秒数 [date: totalSeconds]
    public func monthlyHeatmap(month: Date) -> [Date: Int] {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let end = cal.date(byAdding: .month, value: 1, to: start)
        else { return [:] }
        let summaries = summaryRepo.summaries(from: start, to: end)
        var result: [Date: Int] = [:]
        for s in summaries {
            let day = cal.startOfDay(for: s.date)
            result[day, default: 0] += s.totalSeconds
        }
        return result
    }

    /// 计算指定日期之前的专注记录数
    public func countSessions(before date: Date) -> Int {
        sessionRepo.count(before: date)
    }

    /// 清除指定日期之前的所有数据（session + summary）
    public func clearData(before date: Date) {
        summaryRepo.deleteAll(before: date)
        sessionRepo.deleteAll(before: date)
    }

    /// 清除所有数据，重新开始。返回删除条数
    @discardableResult
    public func clearAllData() -> Int {
        let count = sessionRepo.deleteAll()
        summaryRepo.deleteAll()
        return count
    }

    /// 增量添加单条 session 到 DailySummary（结束/手动添加时使用）
    public func addSessionToSummary(_ session: FocusSession) {
        summaryRepo.upsertDailySummary(for: session)
    }

    /// 全量刷新某日的聚合数据（跨天检测、删除后使用）
    public func refreshDailySummary(for date: Date) {
        summaryRepo.refresh(date: date)
    }

    /// 所有分类（含已归档），供 session 编辑器分类选择使用
    public var allCategories: [FocusCategory] {
        categoryRepo.fetchAll(includeArchived: true)
    }
}

import SwiftData
import Foundation

// ═════════════════════════════════════════════════════════════
//  SummaryRepository — 每日聚合数据访问
//  负责查询和刷新 DailySummary 物化视图
// ═════════════════════════════════════════════════════════════
@MainActor
public final class SummaryRepository {
    private let context: ModelContext

    public init(context: ModelContext? = nil) {
        self.context = context ?? SwiftDataStack.mainContext
    }

    // ──────────────────────────────────────────────
    //  Read
    // ──────────────────────────────────────────────
    public func summary(for date: Date) -> [DailySummary] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 返回指定日期范围内的 DailySummary
    public func summaries(from startDate: Date, to endDate: Date) -> [DailySummary] {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date >= startDate && $0.date < endDate }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 删除指定日期之前的所有聚合数据
    public func deleteAll(before date: Date) {
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date < date }
        )
        guard let toDelete = try? context.fetch(descriptor) else { return }
        toDelete.forEach { context.delete($0) }
        try? context.save()
    }

    /// 返回一年中每天的总专注秒数 [date: totalSeconds]
    public func heatmapData(year: Int) -> [Date: Int] {
        let cal = Calendar.current
        guard let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = cal.date(byAdding: .year, value: 1, to: yearStart)
        else { return [:] }

        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate { $0.date >= yearStart && $0.date < yearEnd }
        )
        let summaries = (try? context.fetch(descriptor)) ?? []

        var result: [Date: Int] = [:]
        for s in summaries {
            let dayStart = cal.startOfDay(for: s.date)
            result[dayStart, default: 0] += s.totalSeconds
        }
        return result
    }

    // ──────────────────────────────────────────────
    //  Write (refresh)
    // ──────────────────────────────────────────────
    public func refresh(date: Date) {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let sessionRepo = SessionRepository(context: context)
        let sessions = sessionRepo.fetch(date: date)

        let grouped = Dictionary(grouping: sessions.filter { $0.durationSeconds >= 30 }) {
            $0.categoryId
        }

        for (catId, catSessions) in grouped {
            let totalSecs = catSessions.reduce(0) { $0 + $1.durationSeconds }
            let count = catSessions.count
            if let existing = findExisting(date: dayStart, categoryId: catId) {
                existing.totalSeconds = totalSecs
                existing.sessionCount = count
                existing.updatedAt = Date()
            } else {
                let summary = DailySummary(
                    date: dayStart,
                    categoryId: catId,
                    totalSeconds: totalSecs,
                    sessionCount: count
                )
                context.insert(summary)
            }
        }
        try? context.save()
    }

    private func findExisting(date: Date, categoryId: UUID) -> DailySummary? {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: date) else { return nil }
        let descriptor = FetchDescriptor<DailySummary>(
            predicate: #Predicate {
                $0.date >= date && $0.date < next && $0.categoryId == categoryId
            }
        )
        return try? context.fetch(descriptor).first
    }
}

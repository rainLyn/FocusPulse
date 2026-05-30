import SwiftData
import Foundation

// ═════════════════════════════════════════════════════════════
//  SessionRepository — 专注记录数据访问
//  所有写操作自动更新关联的 DailySummary
// ═════════════════════════════════════════════════════════════
@MainActor
public final class SessionRepository {
    private let context: ModelContext

    public init(context: ModelContext? = nil) {
        self.context = context ?? SwiftDataStack.mainContext
    }

    // ──────────────────────────────────────────────
    //  Read
    // ──────────────────────────────────────────────
    public func fetchAll() -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func fetch(by id: UUID) -> FocusSession? {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    public func fetch(byCategoryId categoryId: UUID) -> [FocusSession] {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.categoryId == categoryId },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func fetch(date: Date) -> [FocusSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return [] }
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime >= start && $0.startTime < end },
            sortBy: [SortDescriptor(\.startTime)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func count(for categoryId: UUID) -> Int {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.categoryId == categoryId }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// 尚未结束的专注（endTime == nil）
    public func fetchActive() -> FocusSession? {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.endTime == nil }
        )
        return try? context.fetch(descriptor).first
    }

    // ──────────────────────────────────────────────
    //  Write
    // ──────────────────────────────────────────────
    public func insert(_ session: FocusSession) {
        context.insert(session)
        try? context.save()
    }

    public func end(_ session: FocusSession, at endTime: Date = Date()) {
        session.endTime = endTime
        session.durationSeconds = Int(endTime.timeIntervalSince(session.startTime))
        session.updatedAt = endTime
        try? context.save()
    }

    public func delete(_ session: FocusSession) {
        context.delete(session)
        try? context.save()
    }

    /// 删除指定日期之前的所有专注记录，返回删除条数
    @discardableResult
    public func deleteAll(before date: Date) -> Int {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime < date }
        )
        guard let toDelete = try? context.fetch(descriptor) else { return 0 }
        let count = toDelete.count
        toDelete.forEach { context.delete($0) }
        try? context.save()
        return count
    }

    /// 统计指定日期之前的专注记录数
    public func count(before date: Date) -> Int {
        let descriptor = FetchDescriptor<FocusSession>(
            predicate: #Predicate { $0.startTime < date }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}

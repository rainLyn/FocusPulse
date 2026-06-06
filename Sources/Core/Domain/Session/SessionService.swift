import Foundation

// ═════════════════════════════════════════════════════════════
//  Notification — 数据变更通知
//  定义在 Core 层，App 层复用同一名称
// ═════════════════════════════════════════════════════════════
extension Notification.Name {
    public static let dataDidChange = Notification.Name("dataDidChange")
}

// ═════════════════════════════════════════════════════════════
//  SessionService — 单条专注记录管理
//  编辑/删除/手动新增均走同一聚合重建路径
//  保证操作后 DailySummary 始终一致
// ═════════════════════════════════════════════════════════════
@MainActor
public final class SessionService {
    private let sessionRepo: SessionRepository
    private let summaryRepo: SummaryRepository

    public init(
        sessionRepo: SessionRepository? = nil,
        summaryRepo: SummaryRepository? = nil
    ) {
        self.sessionRepo = sessionRepo ?? SessionRepository()
        self.summaryRepo = summaryRepo ?? SummaryRepository()
    }

    // ──────────────────────────────────────────────
    //  Edit
    // ──────────────────────────────────────────────
    public func edit(
        _ session: FocusSession,
        startTime: Date,
        endTime: Date,
        categoryId: UUID
    ) {
        let oldDay = Calendar.current.startOfDay(for: session.startTime)

        session.startTime = startTime
        session.endTime = endTime
        session.categoryId = categoryId
        session.durationSeconds = Int(endTime.timeIntervalSince(startTime))
        session.updatedAt = Date()
        sessionRepo.update(session)

        rebuildAffectedDays(oldDay: oldDay, newDay: Calendar.current.startOfDay(for: startTime))
    }

    // ──────────────────────────────────────────────
    //  Delete
    // ──────────────────────────────────────────────
    public func delete(_ session: FocusSession) {
        let day = Calendar.current.startOfDay(for: session.startTime)
        sessionRepo.delete(session)
        summaryRepo.refresh(date: day)
        NotificationCenter.default.post(name: .dataDidChange, object: nil)
    }

    // ──────────────────────────────────────────────
    //  Manual Create
    // ──────────────────────────────────────────────
    @discardableResult
    public func createManual(
        startTime: Date,
        endTime: Date,
        categoryId: UUID
    ) -> FocusSession {
        let session = FocusSession(
            categoryId: categoryId,
            startTime: startTime,
            endTime: endTime,
            durationSeconds: Int(endTime.timeIntervalSince(startTime))
        )
        sessionRepo.insert(session)
        summaryRepo.refresh(date: Calendar.current.startOfDay(for: startTime))
        NotificationCenter.default.post(name: .dataDidChange, object: nil)
        return session
    }

    // ──────────────────────────────────────────────
    //  Helpers
    // ──────────────────────────────────────────────
    private func rebuildAffectedDays(oldDay: Date, newDay: Date) {
        summaryRepo.refresh(date: oldDay)
        if !Calendar.current.isDate(oldDay, inSameDayAs: newDay) {
            summaryRepo.refresh(date: newDay)
        }
        NotificationCenter.default.post(name: .dataDidChange, object: nil)
    }
}

import SwiftData
import Foundation

// ═════════════════════════════════════════════════════════════
//  DailySummary — 每日聚合（物化视图）
//  每次 FocusSession 写入后异步刷新
//  按 (date, categoryId) 唯一聚集，避免重复
// ═════════════════════════════════════════════════════════════
@Model
public final class DailySummary {
    @Attribute(.unique) public var id: UUID
    public var date: Date
    public var categoryId: UUID
    public var totalSeconds: Int
    public var sessionCount: Int
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        categoryId: UUID,
        totalSeconds: Int = 0,
        sessionCount: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.categoryId = categoryId
        self.totalSeconds = totalSeconds
        self.sessionCount = sessionCount
        self.updatedAt = updatedAt
    }
}

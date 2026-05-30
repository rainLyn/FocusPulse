import SwiftData
import Foundation

// ═════════════════════════════════════════════════════════════
//  FocusSession — 单次专注记录
//  durationSeconds 由 endTime - startTime 自动计算
//  categoryId 为弱引用，分类删除后 record 保留
// ═════════════════════════════════════════════════════════════
@Model
public final class FocusSession {
    @Attribute(.unique) public var id: UUID
    public var categoryId: UUID
    public var startTime: Date
    public var endTime: Date?
    public var durationSeconds: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        categoryId: UUID,
        startTime: Date = Date(),
        endTime: Date? = nil,
        durationSeconds: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.categoryId = categoryId
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

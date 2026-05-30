import SwiftData
import Foundation

// ═════════════════════════════════════════════════════════════
//  FocusCategory — 专注分类
//  名称唯一（忽略大小写），软删除通过 isArchived 标记
//  颜色从 12 色调色板选取，不支持自定义色值
// ═════════════════════════════════════════════════════════════
@Model
public final class FocusCategory {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var colorHex: String
    public var iconName: String
    public var sortOrder: Int
    public var isArchived: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        iconName: String = "folder.fill",
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.iconName = iconName
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

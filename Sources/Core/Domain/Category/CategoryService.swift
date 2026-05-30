import Foundation

// ═════════════════════════════════════════════════════════════
//  CategoryService — 分类业务逻辑
//  负责命名唯一性校验、预设初始化、排序管理
// ═════════════════════════════════════════════════════════════
@MainActor
public final class CategoryService {
    private let repository: CategoryRepository

    public init(repository: CategoryRepository? = nil) {
        self.repository = repository ?? CategoryRepository()
    }

    /// 获取所有未归档分类
    public var categories: [FocusCategory] {
        repository.fetchAll()
    }

    /// 创建分类
    /// 如果有同名已归档分类 → 恢复它并更新颜色/图标（历史数据自然接续）
    /// 否则 → 新建
    public func create(name: String, colorHex: String, iconName: String = "folder.fill") -> FocusCategory? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 12 else { return nil }

        // 同名已归档 → 恢复
        if let archived = repository.fetchArchived(name: trimmed) {
            archived.colorHex = colorHex
            archived.iconName = iconName
            archived.isArchived = false
            repository.update(archived)
            return archived
        }

        guard !repository.exists(name: trimmed) else { return nil }

        let maxOrder = (repository.fetchAll().max(by: { $0.sortOrder < $1.sortOrder })?.sortOrder ?? -1) + 1
        let cat = FocusCategory(
            name: trimmed,
            colorHex: colorHex,
            iconName: iconName,
            sortOrder: maxOrder
        )
        repository.insert(cat)
        return cat
    }

    /// 编辑分类
    public func update(_ category: FocusCategory, name: String, colorHex: String? = nil) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count <= 12 else { return false }

        // 如果改名，检查新名是否与其他分类冲突
        if trimmed.lowercased() != category.name.lowercased(), repository.exists(name: trimmed) {
            return false
        }

        category.name = trimmed
        if let hex = colorHex { category.colorHex = hex }
        repository.update(category)
        return true
    }

    /// 软删除（归档）
    public func archive(_ category: FocusCategory) {
        repository.archive(category)
    }

    /// 批量设置排序
    public func reorder(ids: [UUID]) {
        let ordered = ids.enumerated().map { ($0.element, $0.offset) }
        repository.reorder(ordered)
    }
}

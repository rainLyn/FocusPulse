import SwiftData
import Foundation

// ═════════════════════════════════════════════════════════════
//  CategoryRepository — 分类数据访问
//  数据层唯一入口，ViewModel/Service 不能直接操作 SwiftData
// ═════════════════════════════════════════════════════════════
@MainActor
public final class CategoryRepository {
    private let context: ModelContext

    public init(context: ModelContext? = nil) {
        self.context = context ?? SwiftDataStack.mainContext
    }

    // ──────────────────────────────────────────────
    //  Read
    // ──────────────────────────────────────────────
    public func fetchAll(includeArchived: Bool = false) -> [FocusCategory] {
        let predicate = includeArchived ? nil : #Predicate<FocusCategory> { !$0.isArchived }
        let descriptor = FetchDescriptor<FocusCategory>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func fetch(by id: UUID) -> FocusCategory? {
        let descriptor = FetchDescriptor<FocusCategory>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    public func fetchArchived(name: String) -> FocusCategory? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<FocusCategory>(
            predicate: #Predicate { $0.name == trimmed && $0.isArchived }
        )
        return try? context.fetch(descriptor).first
    }

    public func exists(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<FocusCategory>(
            predicate: #Predicate { $0.name == trimmed && !$0.isArchived }
        )
        return (try? context.fetch(descriptor).isEmpty) == false
    }

    // ──────────────────────────────────────────────
    //  Write
    // ──────────────────────────────────────────────
    public func insert(_ category: FocusCategory) {
        context.insert(category)
        try? context.save()
    }

    public func update(_ category: FocusCategory) {
        try? context.save()
    }

    public func archive(_ category: FocusCategory) {
        category.isArchived = true
        try? context.save()
    }

    public func delete(_ category: FocusCategory) {
        context.delete(category)
        try? context.save()
    }

    public func reorder(_ categories: [(id: UUID, sortOrder: Int)]) {
        for (id, order) in categories {
            guard let cat = fetch(by: id) else { continue }
            cat.sortOrder = order
        }
        try? context.save()
    }
}

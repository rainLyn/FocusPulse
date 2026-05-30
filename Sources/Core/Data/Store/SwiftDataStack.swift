import SwiftData
import Foundation

// ═════════════════════════════════════════════════════════════
//  SwiftDataStack — 数据库配置与容器创建
//  所有 Repository 共享同一个 ModelContainer
//  ⚠️ 不支持 iCloud sync（v2.0 路线图）
// ═════════════════════════════════════════════════════════════
public enum SwiftDataStack {
    public static let container: ModelContainer = {
        let schema = Schema([
            FocusCategory.self,
            FocusSession.self,
            DailySummary.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData 初始化失败: \(error.localizedDescription)")
        }
    }()

    @MainActor
    public static var mainContext: ModelContext {
        container.mainContext
    }

    /// 创建独立子上下文（用于批量写入/后台聚合）
    @MainActor
    public static func newContext() -> ModelContext {
        ModelContext(container)
    }
}

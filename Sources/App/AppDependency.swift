import Foundation
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  AppDependency — 依赖注入容器
//  集中管理所有 Service / Repository 的创建
//  便于测试时替换为 mock
// ═════════════════════════════════════════════════════════════
@MainActor
struct AppDependency {
    let categoryRepository: CategoryRepository
    let sessionRepository: SessionRepository
    let summaryRepository: SummaryRepository
    let categoryService: CategoryService
    let aggregationService: AggregationService
    let sessionService: SessionService
    let preferenceStore: PreferenceStore

    init() {
        self.categoryRepository = CategoryRepository()
        self.sessionRepository = SessionRepository()
        self.summaryRepository = SummaryRepository()
        self.categoryService = CategoryService(repository: categoryRepository)
        self.aggregationService = AggregationService(
            sessionRepo: sessionRepository,
            summaryRepo: summaryRepository,
            categoryRepo: categoryRepository
        )
        self.sessionService = SessionService(
            sessionRepo: sessionRepository,
            summaryRepo: summaryRepository
        )
        self.preferenceStore = PreferenceStore()
    }

    #if DEBUG
    init(
        categoryRepository: CategoryRepository,
        sessionRepository: SessionRepository,
        summaryRepository: SummaryRepository,
        categoryService: CategoryService,
        aggregationService: AggregationService,
        sessionService: SessionService,
        preferenceStore: PreferenceStore
    ) {
        self.categoryRepository = categoryRepository
        self.sessionRepository = sessionRepository
        self.summaryRepository = summaryRepository
        self.categoryService = categoryService
        self.aggregationService = aggregationService
        self.sessionService = sessionService
        self.preferenceStore = preferenceStore
    }
    #endif
}

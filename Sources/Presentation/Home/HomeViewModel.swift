import SwiftUI
import Observation
import FocusPulseCore

// ═══════════════════════════════════════════════════════════════
//  HomeViewModel — 首页状态管理
//  持有分类数据、计时引擎、今日概览
// ═══════════════════════════════════════════════════════════════
@MainActor
@Observable
final class HomeViewModel {
    // 状态
    var categories: [FocusCategory] = []
    var selectedCategoryId: UUID? = nil
    var dailyBreakdown: AggregationService.DailyBreakdown? = nil
    var showTimer = false
    var showCategoryEditor = false
    var editingCategory: FocusCategory? = nil
    var showInterruptionAlert = false
    var interruptionSession: FocusSession? = nil
    var pendingDeleteCategory: FocusCategory? = nil
    var showDeleteConfirmation = false
    var deleteConfirmationMessage = ""
    var isInitialized = false

    /// UI 层显示的秒数
    var displayElapsedSeconds: Int = 0

    let timerEngine = TimerEngine()

    private let categoryService: CategoryService
    private let sessionRepo: SessionRepository
    private let aggregationService: AggregationService
    private let preferenceStore: PreferenceStore
    private var displayTimer: Timer?
    private var dataObserver: NSObjectProtocol?

    init(
        categoryService: CategoryService? = nil,
        sessionRepo: SessionRepository? = nil,
        aggregationService: AggregationService? = nil,
        preferenceStore: PreferenceStore? = nil
    ) {
        self.categoryService = categoryService ?? CategoryService()
        self.sessionRepo = sessionRepo ?? SessionRepository()
        self.aggregationService = aggregationService ?? AggregationService()
        self.preferenceStore = preferenceStore ?? PreferenceStore()

        dataObserver = NotificationCenter.default.addObserver(
            forName: .dataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDaily()
            }
        }
    }

    // ──────────────────────────────────────────────
    //  Init
    // ──────────────────────────────────────────────
    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        reloadCategories()
        checkInterruption()
        refreshDaily()
    }

    // ──────────────────────────────────────────────
    //  Categories
    // ──────────────────────────────────────────────
    func reloadCategories() {
        categories = categoryService.categories
        if selectedCategoryId == nil, let first = categories.first {
            selectedCategoryId = first.id
        }
    }

    func createCategory(name: String, colorHex: String) -> Bool {
        guard let _ = categoryService.create(name: name, colorHex: colorHex) else { return false }
        reloadCategories()
        return true
    }

    func updateCategory(_ cat: FocusCategory, name: String, colorHex: String? = nil) -> Bool {
        guard categoryService.update(cat, name: name, colorHex: colorHex) else { return false }
        reloadCategories()
        return true
    }

    func archiveCategory(_ cat: FocusCategory) {
        categoryService.archive(cat)
        if selectedCategoryId == cat.id { selectedCategoryId = categories.first?.id }
        reloadCategories()
    }

    func deleteCategory(_ cat: FocusCategory) {
        categoryService.archive(cat)
        if selectedCategoryId == cat.id { selectedCategoryId = categories.first?.id }
        reloadCategories()
    }

    func prepareToDelete(_ cat: FocusCategory) {
        pendingDeleteCategory = cat
        let count = sessionRepo.count(for: cat.id)
        deleteConfirmationMessage = "该分类下有 \(count) 条专注记录，删除后数据将隐藏（不删除原始记录）"
        showDeleteConfirmation = true
    }

    func confirmDelete() {
        guard let cat = pendingDeleteCategory else { return }
        archiveCategory(cat)
        cancelDelete()
    }

    func cancelDelete() {
        pendingDeleteCategory = nil
        showDeleteConfirmation = false
    }

    // ──────────────────────────────────────────────
    //  Timer
    // ──────────────────────────────────────────────
    func startFocus() {
        guard let catId = selectedCategoryId else { return }

        timerEngine.start(categoryId: catId)
        displayElapsedSeconds = 0
        startDisplayTimer()
        showTimer = true

        let cat = categories.first(where: { $0.id == catId })
        let name = cat?.name ?? "专注"
        let colorHex = cat?.colorHex ?? "636366"
        LiveActivityService.start(categoryName: name, colorHex: colorHex, startedAt: Date())
    }

    func endFocus() {
        stopDisplayTimer()
        LiveActivityService.end()
        timerEngine.stop()
        guard case .ended(let session) = timerEngine.state else { return }

        // <30s 不记录
        if session.durationSeconds >= 30 {
            sessionRepo.insert(session)
            aggregationService.refreshDailySummary(for: session.startTime)
            updatePreference(session: session)
        }

        showTimer = false
        timerEngine.reset()
        refreshDaily()
        NotificationCenter.default.post(name: .dataDidChange, object: nil)
    }

    func discardFocus() {
        stopDisplayTimer()
        LiveActivityService.end()
        timerEngine.reset()
        displayElapsedSeconds = 0
        showTimer = false
    }

    // ──────────────────────────────────────────────
    //  Daily Stats
    // ──────────────────────────────────────────────
    func refreshDaily() {
        dailyBreakdown = aggregationService.dailyBreakdown(for: Date())
    }

    // ──────────────────────────────────────────────
    //  Interruption Recovery
    // ──────────────────────────────────────────────
    private func checkInterruption() {
        guard let active = sessionRepo.fetchActive() else { return }
        let elapsed = Int(Date().timeIntervalSince(active.startTime))
        guard elapsed >= 30 else {
            sessionRepo.delete(active)
            return
        }
        interruptionSession = active
        showInterruptionAlert = true
    }

    func acceptInterruption() {
        guard let session = interruptionSession else { return }
        let end = Date()
        sessionRepo.end(session, at: end)
        aggregationService.refreshDailySummary(for: session.startTime)
        updatePreference(session: session)
        interruptionSession = nil
        showInterruptionAlert = false
        refreshDaily()
    }

    func discardInterruption() {
        guard let session = interruptionSession else { return }
        sessionRepo.delete(session)
        interruptionSession = nil
        showInterruptionAlert = false
    }

    // ──────────────────────────────────────────────
    //  App Lifecycle
    // ──────────────────────────────────────────────
    func appDidBecomeActive() {
        let prefs = preferenceStore.load()
        if let lastDate = prefs.lastActiveDate {
            if !Calendar.current.isDateInToday(lastDate) {
                aggregationService.refreshDailySummary(for: lastDate)
            }
        }
        preferenceStore.update { $0.lastActiveDate = Date() }
        refreshDaily()
        reloadCategories()
    }

    // ──────────────────────────────────────────────
    //  Private — Timer
    // ──────────────────────────────────────────────
    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.displayElapsedSeconds = self.timerEngine.computeElapsed()
            }
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func updatePreference(session: FocusSession) {
        preferenceStore.update { pref in
            pref.totalLifetimeSeconds += session.durationSeconds
        }
    }
}
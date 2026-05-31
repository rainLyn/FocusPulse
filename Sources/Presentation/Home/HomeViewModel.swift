import SwiftUI
import Observation
import FocusPulseCore

// ═══════════════════════════════════════════════════════════════
//  HomeViewModel — 首页状态管理
//  持有分类数据、计时引擎、今日概览
//
//  真相源: FocusSession (endTime == nil) 即表示计时中
//  TimerEngine / LiveActivity / displayElapsedSeconds 都派生于此
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
    var pendingDeleteCategory: FocusCategory? = nil
    var showDeleteConfirmation = false
    var deleteConfirmationMessage = ""
    var isInitialized = false

    /// UI 层显示的秒数
    var displayElapsedSeconds: Int = 0

    let timerEngine = TimerEngine()

    /// 当前活跃的专注 session（DB 中 endTime==nil 的那条）
    private var activeSession: FocusSession? = nil

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
        restoreActiveSessionIfNeeded()
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

        /* 用同一个时间戳，确保 TimerEngine 和 LiveActivity 完全同步 */
        let now = Date()

        /* 先持久化 session —— 这是唯一的真相源 */
        let session = FocusSession(
            categoryId: catId,
            startTime: now,
            endTime: nil,
            durationSeconds: 0
        )
        activeSession = session
        sessionRepo.insert(session)

        /* 从持久化 session 恢复引擎状态 */
        timerEngine.restore(session: session, currentTime: now)
        displayElapsedSeconds = 0
        startDisplayTimer()
        showTimer = true

        let cat = categories.first(where: { $0.id == catId })
        LiveActivityService.start(
            categoryName: cat?.name ?? "专注",
            colorHex: cat?.colorHex ?? "636366",
            startedAt: now
        )
    }

    func endFocus() {
        stopDisplayTimer()
        LiveActivityService.end()

        guard let session = activeSession else { return }
        let now = Date()
        let duration = Int(now.timeIntervalSince(session.startTime))

        timerEngine.reset()

        if duration >= 30 {
            sessionRepo.end(session, at: now)
            aggregationService.refreshDailySummary(for: session.startTime)
            updatePreference(session: session)
        } else {
            sessionRepo.delete(session)
        }

        activeSession = nil
        showTimer = false
        refreshDaily()
        NotificationCenter.default.post(name: .dataDidChange, object: nil)
    }

    func discardFocus() {
        stopDisplayTimer()
        LiveActivityService.end()

        if let session = activeSession {
            sessionRepo.delete(session)
        }
        activeSession = nil

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
    //  Interruption Recovery —— 无缝恢复，不弹窗
    // ──────────────────────────────────────────────
    private func restoreActiveSessionIfNeeded() {
        guard let active = sessionRepo.fetchActive() else { return }
        let elapsed = Int(Date().timeIntervalSince(active.startTime))

        /* 小于 30s 的僵尸 session 直接清理 */
        guard elapsed >= 30 else {
            sessionRepo.delete(active)
            return
        }

        /* 无缝恢复：timer 界面直接出现，用户无感知 */
        activeSession = active
        timerEngine.restore(session: active)
        showTimer = true
        startDisplayTimer()

        /* 重新创建 Live Activity（旧的随 App 被杀可能已失效） */
        let cat = categories.first(where: { $0.id == active.categoryId })
        LiveActivityService.restart(
            categoryName: cat?.name ?? "专注",
            colorHex: cat?.colorHex ?? "636366",
            startedAt: active.startTime
        )
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

        /* 回到前台时，如果计时界面未展示但有活跃 session，恢复之
           覆盖场景：用户在计时中通过通知中心点击回到 App */
        if !showTimer, let active = sessionRepo.fetchActive() {
            activeSession = active
            timerEngine.restore(session: active)
            showTimer = true
            startDisplayTimer()
        }
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

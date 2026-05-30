import SwiftUI
import Observation
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  StatisticsViewModel — 统计页状态管理
//  饼图日期展示、时段明细、月历热力图、月份导航、数据清除、CSV 导出
// ═════════════════════════════════════════════════════════════
@MainActor
@Observable
final class StatisticsViewModel {
    var currentDate = Date()
    var dailyBreakdown: AggregationService.DailyBreakdown? = nil
    var sessionTimeline: [(FocusSession, String, String)] = []

    // 清除数据
    var showClearDataSheet = false
    var clearCutoffDate = Date()
    var showClearConfirmation = false
    var pendingDeletionCount = 0
    var pendingClearDate: Date?

    // 月份选择器
    var showMonthPicker = false
    var pickerYear = 0
    var pickerMonth = 0

    // 月历
    var monthlyHeatmap: [Date: Int] = [:]

    // 导出
    var exportDocument: CSVDocument?
    var showExportPicker = false

    private let aggregationService: AggregationService
    private let exportService: ExportService
    private var dataObserver: NSObjectProtocol?

    init(
        aggregationService: AggregationService? = nil,
        exportService: ExportService? = nil
    ) {
        self.aggregationService = aggregationService ?? AggregationService()
        self.exportService = exportService ?? ExportService()

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

    func refresh() {
        refreshDaily()
    }

    func refreshDaily() {
        dailyBreakdown = aggregationService.dailyBreakdown(for: currentDate)
        sessionTimeline = aggregationService.sessionTimeline(for: currentDate)
        monthlyHeatmap = aggregationService.monthlyHeatmap(month: currentDate)
    }

    // ── 月份切换 ──
    func goToPreviousMonth() {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: currentDate) else { return }
        currentDate = prev
        refreshDaily()
    }

    func goToNextMonth() {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: currentDate) else { return }
        let now = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        let nxt = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: next))!
        if nxt > now { return }
        currentDate = next
        refreshDaily()
    }

    var isCurrentMonth: Bool {
        Calendar.current.isDate(currentDate, equalTo: Date(), toGranularity: .month)
    }

    // ── 月份选择器 ──
    func selectDate(_ date: Date) {
        currentDate = date
        refreshDaily()
    }

    func confirmMonthPicker() {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: currentDate)
        comps.year = pickerYear
        comps.month = pickerMonth
        comps.day = 1
        if let date = Calendar.current.date(from: comps) {
            let now = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
            let picked = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: date))!
            if picked > now { return }
            currentDate = date
        }
        showMonthPicker = false
        refreshDaily()
    }

    // ── 清除数据 ──
    func prepareClearData() {
        let count = aggregationService.countSessions(before: clearCutoffDate)
        guard count > 0 else {
            showClearDataSheet = false
            return
        }
        pendingDeletionCount = count
        pendingClearDate = clearCutoffDate
        showClearDataSheet = false
        showClearConfirmation = true
    }

    func confirmClearData() {
        guard let date = pendingClearDate else { return }
        aggregationService.clearData(before: date)
        pendingClearDate = nil
        showClearConfirmation = false
        refreshDaily()
        NotificationCenter.default.post(name: .dataDidChange, object: nil)
    }

    func cancelClearData() {
        pendingClearDate = nil
        pendingDeletionCount = 0
        showClearConfirmation = false
    }

    // ── CSV 导出 ──
    func prepareExport() {
        let result = exportService.exportCSV()
        exportDocument = CSVDocument(data: result.data)
        showExportPicker = true
    }
}

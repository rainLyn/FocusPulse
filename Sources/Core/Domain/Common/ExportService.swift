import Foundation

// ═════════════════════════════════════════════════════════════
//  ExportService — 专注统计导出
//  每天一行宽表格式：日期,总时长,分类1,分类2,...
//  基于 DailySummary，不遍历原始 session
// ═════════════════════════════════════════════════════════════
public struct ExportResult {
    public let data: Data
    public let fileName: String
}

@MainActor
public final class ExportService {
    private let summaryRepo: SummaryRepository
    private let sessionRepo: SessionRepository
    private let categoryRepo: CategoryRepository

    public init(
        summaryRepo: SummaryRepository? = nil,
        sessionRepo: SessionRepository? = nil,
        categoryRepo: CategoryRepository? = nil
    ) {
        self.summaryRepo = summaryRepo ?? SummaryRepository()
        self.sessionRepo = sessionRepo ?? SessionRepository()
        self.categoryRepo = categoryRepo ?? CategoryRepository()
    }

    /// 导出按天聚合统计 CSV
    /// 格式：日期,总时长,分类1,分类2,...
    /// 每行一天，分类水平展开
    public func exportCSV() -> ExportResult {
        let cats = categoryRepo.fetchAll(includeArchived: true)

        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"

        let allSessions = sessionRepo.fetchAll()
        guard let earliest = allSessions.min(by: { $0.startTime < $1.startTime })?.startTime else {
            let empty = "日期,总时长\n"
            return ExportResult(data: Data(empty.utf8),
                                fileName: "FocusPulse_\(ISO8601DateFormatter().string(from: Date())).csv")
        }

        let cal = Calendar.current
        let startDay = cal.startOfDay(for: earliest)
        guard let endDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) else {
            fatalError()
        }

        let summaries = summaryRepo.summaries(from: startDay, to: endDay)
        let grouped = Dictionary(grouping: summaries) { cal.startOfDay(for: $0.date) }

        // 收集所有有记录的分类，按 sortOrder 排序
        let allCatIds = Set(summaries.map(\.categoryId))
        let sortedCats = cats.filter { allCatIds.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }

        // 表头
        var csv = "日期,总时长"
        for cat in sortedCats {
            csv += ",\(escapeCSV(cat.name))"
        }
        csv += "\n"

        // 数据行
        let sortedDays = grouped.keys.sorted()
        for day in sortedDays {
            let daySummaries = grouped[day]!
            let dayTotal = daySummaries.reduce(0) { $0 + $1.totalSeconds }
            let dayStr = dayFmt.string(from: day)

            csv += "\(dayStr),\(dayTotal.prettyFormat)"

            let catSeconds = Dictionary(uniqueKeysWithValues: daySummaries.map {
                ($0.categoryId, $0.totalSeconds)
            })

            for cat in sortedCats {
                let secs = catSeconds[cat.id] ?? 0
                csv += ",\(secs > 0 ? secs.prettyFormat : "0")"
            }
            csv += "\n"
        }

        let fileName = "FocusPulse_\(ISO8601DateFormatter().string(from: Date())).csv"
        return ExportResult(data: Data(csv.utf8), fileName: fileName)
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
}

import SwiftUI

// ═════════════════════════════════════════════════════════════
//  CalendarHeatmapView — 月历热力图
//  每天格子内显示总专注时长，按时长深浅着色
//  点击日期查看当日明细
// ═════════════════════════════════════════════════════════════
struct CalendarHeatmapView: View {
    let month: Date
    let heatmap: [Date: Int]
    let selectedDate: Date
    let onSelect: (Date) -> Void

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekDays = ["日", "一", "二", "三", "四", "五", "六"]

    // GitHub 风格绿色热力色阶（中 → 最深）
    private static let greenLevels: [Color] = [
        Color(red: 0.25, green: 0.77, blue: 0.39),  // #40c463  2h~4h  中
        Color(red: 0.19, green: 0.63, blue: 0.31),  // #30a14e  4h~6h  深
        Color(red: 0.13, green: 0.43, blue: 0.21),  // #216e39  6h+    最深
    ]

    var body: some View {
        VStack(spacing: 6) {
            // 星期行
            HStack(spacing: 2) {
                ForEach(weekDays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 日期网格
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(dayCells, id: \.offset) { offset, date in
                    if let date = date {
                        dayCell(date: date)
                            .onTapGesture {
                                HapticService.selection()
                                onSelect(date)
                            }
                    } else {
                        Color.clear
                            .aspectRatio(1, contentMode: .fill)
                    }
                }
            }
        }
    }

    // ── 日期格子 ──
    private func dayCell(date: Date) -> some View {
        let dayStart = cal.startOfDay(for: date)
        let duration = heatmap[dayStart] ?? 0
        let isSelected = cal.isDate(dayStart, inSameDayAs: selectedDate)
        let isFuture = date > Date()
        let level = heatLevel(seconds: duration)
        let hasGreen = isSelected || level >= 0
        let fg: Color = isFuture ? .gray : (hasGreen ? .white : .primary)
        let durationFg: Color = isFuture ? .gray.opacity(0.3) : (hasGreen ? .white.opacity(0.9) : .secondary)

        return VStack(spacing: 1) {
            Text("\(cal.component(.day, from: date))")
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(fg)

            Text(durationText(duration))
                .font(.system(size: 8))
                .foregroundStyle(durationFg)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(dayBackground(isFuture: isFuture, isSelected: isSelected, duration: duration))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color(red: 0.10, green: 0.35, blue: 0.17) : Color.clear, lineWidth: 1.5)
        )
    }

    private func dayBackground(isFuture: Bool, isSelected: Bool, duration: Int) -> Color {
        if isSelected { return Self.greenLevels[2] }
        if isFuture || duration <= 0 { return Color(.systemGray6) }
        let level = heatLevel(seconds: duration)
        if level < 0 { return Color(.systemGray6) }
        return Self.greenLevels[level]
    }

    // 按绝对专注时长分档（秒 → -1~3, -1 不显示绿色）
    private func heatLevel(seconds: Int) -> Int {
        if seconds <= 0 { return -1 }
        if seconds < 7200       { return 0 }   // < 2h  中
        if seconds < 14400      { return 1 }   // 2h~4h 深
        return 2                                // 4h+   最深
    }

    // ── 计算属性 ──
    private var dayCells: [(offset: Int, date: Date?)] {
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let monthRange = cal.range(of: .day, in: .month, for: monthStart)
        else { return [] }

        let firstWeekday = cal.component(.weekday, from: monthStart)
        let leading = firstWeekday - 1 // 周日 = 1
        let daysInMonth = monthRange.count

        var cells: [(offset: Int, date: Date?)] = []
        var i = 0

        // 前置空白
        for _ in 0..<leading {
            cells.append((i, nil))
            i += 1
        }

        // 当月日期
        for day in 0..<daysInMonth {
            let date = cal.date(byAdding: .day, value: day, to: monthStart)!
            cells.append((i, date))
            i += 1
        }

        // 后置空白（补齐最后一周）
        let trailing = (7 - cells.count % 7) % 7
        for _ in 0..<trailing {
            cells.append((i, nil))
            i += 1
        }

        return cells
    }

    private func durationText(_ seconds: Int) -> String {
        if seconds < 60 { return "" }
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h"
    }
}

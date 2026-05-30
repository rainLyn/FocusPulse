import SwiftUI
import Charts
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  PieChartView — Swift Charts 饼图
//  按分类着色，显示占比
// ═════════════════════════════════════════════════════════════
struct PieChartView: View {
    let breakdown: AggregationService.DailyBreakdown?

    var body: some View {
        Group {
            if let breakdown = breakdown, !breakdown.items.isEmpty {
                Chart(breakdown.items) { item in
                    SectorMark(
                        angle: .value("时长", item.seconds),
                        innerRadius: .ratio(0.5),
                        outerRadius: .ratio(1.0)
                    )
                    .foregroundStyle(ColorPalette.color(item.colorHex))
                    .annotation(position: .overlay) {
                        if item.percentage > 0.08 {
                            Text("\(Int(item.percentage * 100))%")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: breakdown.totalSeconds)
            } else {
                EmptyStateView(
                    icon: "chart.pie",
                    message: "今天还没有专注记录\n去学点什么吧"
                )
            }
        }
    }
}

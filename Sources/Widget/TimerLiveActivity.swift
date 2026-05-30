import WidgetKit
import SwiftUI
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  TimerLiveActivity — 锁屏实时计时 + 灵动岛
//  Text(.timer) 系统自动计数，App 挂起也能刷新
// ═════════════════════════════════════════════════════════════
@main
struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .foregroundColor(Color(hex: context.attributes.colorHex))
                        Text(context.attributes.categoryName)
                            .font(.caption2)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.startedAt, style: .timer)
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundColor(Color(hex: context.attributes.colorHex))
            } compactTrailing: {
                Text(context.attributes.categoryName)
                    .font(.caption2)
                    .lineLimit(1)
            } minimal: {
                Image(systemName: "timer")
                    .foregroundColor(Color(hex: context.attributes.colorHex))
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: context.attributes.colorHex))
            Text(context.attributes.categoryName)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(context.attributes.startedAt, style: .timer)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .activityBackgroundTint(.black.opacity(0.2))
    }
}

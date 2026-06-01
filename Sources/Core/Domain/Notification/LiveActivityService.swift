import Foundation
import OSLog
@preconcurrency import ActivityKit

// ═════════════════════════════════════════════════════════════
//  LiveActivityService — Live Activity 生命周期管理
//  计时开始 → 启动锁屏实时显示（Text(.timer) 自动计数）
//  计时结束 → 立即移除
//  无需 update：计时由系统驱动，App 挂起也能刷新
// ═════════════════════════════════════════════════════════════
@MainActor
public enum LiveActivityService {
    private static let logger = Logger(
        subsystem: "com.focuspulse.app",
        category: "LiveActivity"
    )
    private static var currentActivity: Activity<TimerActivityAttributes>?

    /// 启动 Live Activity（计时开始时调用）
    public static func start(categoryName: String, colorHex: String, startedAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = TimerActivityAttributes(
            startedAt: startedAt,
            categoryName: categoryName,
            colorHex: colorHex
        )
        let state = TimerActivityAttributes.TimerContentState()
        let content = ActivityContent(state: state, staleDate: nil)

        do {
            currentActivity = try Activity<TimerActivityAttributes>.request(
                attributes: attributes,
                content: content
            )
            logger.info("Live Activity 启动成功: \(categoryName)")
        } catch {
            logger.error("Live Activity 启动失败: \(error.localizedDescription)")
        }
    }

    /// 结束 Live Activity（计时停止/丢弃时调用）
    public static func end() {
        let activity = currentActivity
        currentActivity = nil
        guard let activity else { return }
        Task {
            let finalContent = ActivityContent(
                state: TimerActivityAttributes.TimerContentState(),
                staleDate: nil
            )
            await activity.end(finalContent, dismissalPolicy: .immediate)
            logger.info("Live Activity 已结束")
        }
    }

    /// 无缝重启 Live Activity（App 被杀后恢复时调用）
    /// 先等待旧 activity 全部结束，再用正确的 startedAt 启动新的
    public static func restart(categoryName: String, colorHex: String, startedAt: Date) async {
        let existing = Activity<TimerActivityAttributes>.activities
        for activity in existing {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        start(categoryName: categoryName, colorHex: colorHex, startedAt: startedAt)
    }
}

import Foundation
@preconcurrency import ActivityKit

// ═════════════════════════════════════════════════════════════
//  TimerActivityAttributes — Live Activity 数据模型
//  Text(.timer) 由系统自动计数，App 挂起也能刷新
// ═════════════════════════════════════════════════════════════
public struct TimerActivityAttributes: ActivityAttributes {
    public typealias ContentState = TimerContentState

    public struct TimerContentState: Codable, Hashable, Sendable {}

    /// 计时开始时间戳（供 Text(.timer) 系统级自动计数）
    public var startedAt: Date
    /// 分类名
    public var categoryName: String
    /// 分类颜色（hex 字符串）
    public var colorHex: String
}

import UIKit

// ═════════════════════════════════════════════════════════════
//  HapticService — 统一触感反馈
//  所有 Haptic 调用走这里，方便调试和替换
// ═════════════════════════════════════════════════════════════
@MainActor
enum HapticService {
    /// 轻度触碰 —— 按钮点击、选中
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// 中度触碰 —— 开始专注、切换
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// 成功通知 —— 专注结束
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 警告 —— 误触、异常
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// 选中 —— 分类选择、日历日期
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

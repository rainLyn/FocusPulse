import SwiftUI

// ═════════════════════════════════════════════════════════════
//  PressAnimation — 卡片按压弹性动画
//  使用场景：分类卡片、按钮、可点击区域
// ═════════════════════════════════════════════════════════════
struct PressAnimation: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// 给任意 View 添加按压弹性效果
    func pressAnimation() -> some View {
        self.buttonStyle(PressAnimation())
    }
}

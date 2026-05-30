import SwiftUI

// ═════════════════════════════════════════════════════════════
//  TimerDisplayView — 计时数字组件
//  hh:mm:ss 格式，每秒刷新
// ═════════════════════════════════════════════════════════════
struct TimerDisplayView: View {
    let elapsedSeconds: Int
    let isRunning: Bool

    var body: some View {
        Text(elapsedSeconds.hmsFormat)
            .font(.system(size: 64, weight: .thin, design: .monospaced))
            .foregroundStyle(.primary)
            .contentTransition(.numericText(countsDown: false))
            .animation(.default, value: elapsedSeconds)
    }
}

import SwiftUI
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  ActiveTimerView — 全屏计时视图
//  显示计时器、当前分类、结束/放弃按钮
// ═════════════════════════════════════════════════════════════
struct ActiveTimerView: View {
    let vm: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    private var backgroundFill: Color {
        Color(.systemBackground)
    }

    var body: some View {
        ZStack {
            backgroundFill
                .ignoresSafeArea()

            VStack(spacing: 40) {
                categoryLabel
                    .transition(.opacity)

                Spacer()

                TimerDisplayView(
                    elapsedSeconds: vm.displayElapsedSeconds,
                    isRunning: true
                )
                .transition(.scale.combined(with: .opacity))

                Spacer()

                VStack(spacing: 16) {
                    endButton
                    discardButton
                }
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .padding()
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: vm.displayElapsedSeconds != 0)
        }
        .interactiveDismissDisabled()
    }

    private var categoryLabel: some View {
        let catId = vm.timerEngine.currentCategoryId ?? vm.selectedCategoryId
        let cat = vm.categories.first { $0.id == catId }

        return Group {
            if let c = cat {
                HStack(spacing: 8) {
                    Circle()
                        .fill(ColorPalette.color(c.colorHex))
                        .frame(width: 12, height: 12)
                    Text(c.name)
                        .font(.title3.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private var endButton: some View {
        Button(action: {
            HapticService.success()
            vm.endFocus()
            dismiss()
        }) {
            Label("结束专注", systemImage: "stop.fill")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(.white)
        }
        .pressAnimation()
        .padding(.horizontal, 32)
    }

    private var discardButton: some View {
        Button(role: .destructive) {
            HapticService.warning()
            vm.discardFocus()
            dismiss()
        } label: {
            Text("放弃本次记录")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

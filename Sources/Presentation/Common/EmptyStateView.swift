import SwiftUI

// ═════════════════════════════════════════════════════════════
//  EmptyStateView — 通用空状态占位
//  插画（SF Symbol）+ 引导文字 + 可选按钮
// ═════════════════════════════════════════════════════════════
struct EmptyStateView: View {
    let icon: String
    let message: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let label = actionLabel, let action = action {
                Button(label, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

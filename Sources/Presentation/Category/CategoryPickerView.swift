import SwiftUI
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  CategoryPickerView — 纵向分类列表
//  Settings 风格，点击选中，滑动删除
// ═════════════════════════════════════════════════════════════
struct CategoryPickerView: View {
    let categories: [FocusCategory]
    @Binding var selectedId: UUID?
    var onDelete: ((FocusCategory) -> Void)?

    var body: some View {
        List {
            Section("") {
                ForEach(categories) { cat in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(ColorPalette.color(cat.colorHex))
                            .frame(width: 12, height: 12)

                        Text(cat.name)
                            .font(.body)

                        Spacer()

                        if selectedId == cat.id {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(ColorPalette.color(cat.colorHex))
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticService.selection()
                        selectedId = cat.id
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { categories[$0] }.forEach { onDelete?($0) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

import SwiftUI
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  CategoryEditView — 创建/编辑分类
//  名称 1-12 字符 + 12 色调色板选择
// ═════════════════════════════════════════════════════════════
struct CategoryEditView: View {
    @Environment(\.dismiss) private var dismiss

    let category: FocusCategory?
    let onSave: (String, String) -> Bool

    @State private var name: String = ""
    @State private var selectedColor: String = ColorPalette.all[0]
    @State private var errorMessage: String? = nil

    private var isEditMode: Bool { category != nil }

    init(category: FocusCategory? = nil, onSave: @escaping (String, String) -> Bool) {
        self.category = category
        self.onSave = onSave
        if let cat = category {
            _name = State(initialValue: cat.name)
            _selectedColor = State(initialValue: cat.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("名称") {
                    TextField("最多 12 个字符", text: $name)
                        .onChange(of: name) { _, _ in errorMessage = nil }
                        .onSubmit(commit)
                }

                Section("颜色") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 6), spacing: 12) {
                        ForEach(ColorPalette.all, id: \.self) { hex in
                            Circle()
                                .fill(ColorPalette.color(hex))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(hex == selectedColor ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture { selectedColor = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditMode ? "编辑分类" : "新建分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: commit)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 300, minHeight: 400)
    }

    private func commit() {
        guard onSave(name, selectedColor) else {
            errorMessage = "名称已存在或格式错误"
            return
        }
        HapticService.success()
        dismiss()
    }
}

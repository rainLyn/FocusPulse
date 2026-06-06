import SwiftUI
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  SessionEditView — 新增/编辑专注记录
//  session == nil → 新增模式，session != nil → 编辑模式
//  通过消除特殊情况，一个视图覆盖两个用例
// ═════════════════════════════════════════════════════════════
struct SessionEditView: View {
    @Environment(\.dismiss) private var dismiss

    let session: FocusSession?
    let categories: [FocusCategory]
    let onSave: (Date, Date, UUID) -> Bool
    let onDelete: (() -> Void)?

    @State private var categoryId: UUID
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var errorMessage: String?

    private var isEditMode: Bool { session != nil }

    init(
        session: FocusSession?,
        categories: [FocusCategory],
        onSave: @escaping (Date, Date, UUID) -> Bool,
        onDelete: (() -> Void)? = nil
    ) {
        self.session = session
        self.categories = categories
        self.onSave = onSave
        self.onDelete = onDelete

        let now = Date()
        if let s = session {
            _categoryId = State(initialValue: s.categoryId)
            _startTime = State(initialValue: s.startTime)
            _endTime = State(initialValue: s.endTime ?? s.startTime.addingTimeInterval(1800))
        } else {
            let cal = Calendar.current
            let defaultStart = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
            _categoryId = State(initialValue: categories.first?.id ?? UUID())
            _startTime = State(initialValue: defaultStart)
            _endTime = State(initialValue: defaultStart.addingTimeInterval(1800))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                categorySection
                timeSection
                durationSection

                if let err = errorMessage {
                    Section {
                        Text(err).foregroundStyle(.red)
                    }
                }

                if isEditMode {
                    deleteSection
                }
            }
            .navigationTitle(isEditMode ? "编辑记录" : "新增记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: commit)
                }
            }
        }
    }

    // ── 分类选择 ──
    private var categorySection: some View {
        Section("分类") {
            if categories.isEmpty {
                Text("暂无可用分类")
                    .foregroundStyle(.secondary)
            } else {
                Picker("分类", selection: $categoryId) {
                    ForEach(categories) { cat in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ColorPalette.color(cat.colorHex))
                                .frame(width: 10, height: 10)
                            Text(cat.name)
                            if cat.isArchived {
                                Text("(已归档)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(cat.id)
                    }
                }
            }
        }
    }

    // ── 时间区间 ──
    private var timeSection: some View {
        Group {
            Section("开始时间") {
                DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .onChange(of: startTime) { _, _ in errorMessage = nil }
            }

            Section("结束时间") {
                DatePicker("", selection: $endTime, in: startTime...Date.distantFuture,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .onChange(of: endTime) { _, _ in errorMessage = nil }
            }
        }
    }

    // ── 时长 ──
    private var durationSection: some View {
        Section("持续时长") {
            HStack {
                Text(durationSeconds.prettyFormat)
                    .font(.title3.weight(.medium).monospacedDigit())
                Spacer()
                Text(durationSeconds.hmsFormat)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // ── 删除 ──
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                onDelete?()
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("删除此记录")
                    Spacer()
                }
            }
        }
    }

    // ── 计算属性 ──
    private var durationSeconds: Int {
        max(0, Int(endTime.timeIntervalSince(startTime)))
    }

    // ── 提交 ──
    private func commit() {
        guard endTime > startTime else {
            errorMessage = "结束时间必须晚于开始时间"
            return
        }
        guard durationSeconds >= 30 else {
            errorMessage = "专注时长不能少于 30 秒"
            return
        }
        guard onSave(startTime, endTime, categoryId) else {
            errorMessage = "保存失败，请重试"
            return
        }
        HapticService.success()
        dismiss()
    }
}

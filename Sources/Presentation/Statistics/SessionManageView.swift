import SwiftUI
import FocusPulseCore

// ═══════════════════════════════════════════════════════════════
//  SessionManageView — 按天管理专注记录
//  选定日期 → 列出当天所有 session → 滑动删除 / 手动添加
// ═══════════════════════════════════════════════════════════════
struct SessionManageView: View {
    @State private var selectedDate: Date
    @State private var sessions: [(FocusSession, String, String)] = []
    @State private var categories: [FocusCategory] = []
    @State private var showAddSheet = false
    @State private var showDeleteAlert = false
    @State private var sessionToDelete: FocusSession? = nil

    let onDataChanged: () -> Void

    private let aggregationService = AggregationService()
    private let sessionRepo = SessionRepository()
    private let categoryService = CategoryService()

    init(initialDate: Date, onDataChanged: @escaping () -> Void) {
        self._selectedDate = State(initialValue: initialDate)
        self.onDataChanged = onDataChanged
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dateHeader
                Divider()
                sessionList
            }
            .navigationTitle("管理记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddSessionView(
                    selectedDate: selectedDate,
                    categories: categories,
                    onSave: { catId, start, end in
                        addSession(categoryId: catId, start: start, end: end)
                    }
                )
            }
            .onAppear {
                categories = categoryService.categories
                refreshSessions()
            }
            .onChange(of: selectedDate) { _, _ in refreshSessions() }
            .alert("删除记录", isPresented: $showDeleteAlert) {
                Button("取消", role: .cancel) { sessionToDelete = nil }
                Button("删除", role: .destructive) {
                    if let s = sessionToDelete { deleteSession(s) }
                    sessionToDelete = nil
                }
            } message: {
                if let s = sessionToDelete {
                    Text("删除 \(s.startTime.formatted(date: .numeric, time: .shortened)) 的专注记录？\n时长: \(s.durationSeconds.prettyFormat)，此操作不可撤销。")
                }
            }
        }
    }

    // ── 日期选择头 ──
    private var dateHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Button { shiftDay(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                Spacer()
                Button { shiftDay(1) } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(isToday)
            }
            .padding(.horizontal, 16)

            Text(selectedDate, format: .dateTime.year().month().day().weekday(.wide))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    // ── Session 列表 ──
    private var sessionList: some View {
        Group {
            if sessions.isEmpty {
                EmptyStateView(
                    icon: "clock.badge.questionmark",
                    message: "当天没有专注记录"
                )
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(sessions, id: \.0.id) { item in
                        sessionRow(item)
                    }
                    .onDelete { offsets in
                        guard let idx = offsets.first else { return }
                        sessionToDelete = sessions[idx].0
                        showDeleteAlert = true
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func sessionRow(_ item: (FocusSession, String, String)) -> some View {
        let (session, name, colorHex) = item
        return HStack(spacing: 12) {
            Circle()
                .fill(ColorPalette.color(colorHex))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.medium))
                Text(session.startTime.formatted(date: .omitted, time: .shortened)
                     + " - "
                     + (session.endTime ?? session.startTime).formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(session.durationSeconds.prettyFormat)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    // ── Actions ──
    private func shiftDay(_ days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) else { return }
        if date > Date() { return }
        selectedDate = date
    }

    private func refreshSessions() {
        sessions = aggregationService.sessionTimeline(for: selectedDate)
    }

    private func deleteSession(_ session: FocusSession) {
        sessionRepo.delete(session)
        aggregationService.refreshDailySummary(for: session.startTime)
        refreshSessions()
        onDataChanged()
    }

    private func addSession(categoryId: UUID, start: Date, end: Date) {
        let duration = Int(end.timeIntervalSince(start))
        guard duration >= 30 else { return }
        let session = FocusSession(
            categoryId: categoryId,
            startTime: start,
            endTime: end,
            durationSeconds: duration
        )
        sessionRepo.insert(session)
        aggregationService.addSessionToSummary(session)
        refreshSessions()
        onDataChanged()
    }
}

// ═══════════════════════════════════════════════════════════════
//  AddSessionView — 手动添加专注记录表单
// ═══════════════════════════════════════════════════════════════
private struct AddSessionView: View {
    let selectedDate: Date
    let categories: [FocusCategory]
    let onSave: (UUID, Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategoryId: UUID?
    @State private var startTime: Date
    @State private var endTime: Date

    init(selectedDate: Date, categories: [FocusCategory],
         onSave: @escaping (UUID, Date, Date) -> Void) {
        self.selectedDate = selectedDate
        self.categories = categories
        self.onSave = onSave

        /* 默认开始时间为选中日期的当前时刻（或当日 9:00） */
        let cal = Calendar.current
        let now = Date()
        let start: Date
        if cal.isDate(selectedDate, inSameDayAs: now) {
            start = now
        } else {
            start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDate) ?? selectedDate
        }
        self._startTime = State(initialValue: start)
        self._endTime = State(initialValue: start.addingTimeInterval(25 * 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                categorySection
                startTimeSection
                endTimeSection
                summarySection
            }
            .navigationTitle("添加记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(selectedCategoryId == nil)
                }
            }
        }
    }

    private var categorySection: some View {
        Section("分类") {
            if categories.isEmpty {
                Text("请先创建分类")
                    .foregroundStyle(.secondary)
            } else {
                Picker("选择分类", selection: $selectedCategoryId) {
                    Text("未选择").tag(nil as UUID?)
                    ForEach(categories) { cat in
                        HStack {
                            Circle()
                                .fill(ColorPalette.color(cat.colorHex))
                                .frame(width: 10, height: 10)
                            Text(cat.name)
                        }
                        .tag(cat.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var startTimeSection: some View {
        Section("开始时间") {
            DatePicker("", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
        }
    }

    private var endTimeSection: some View {
        Section("结束时间") {
            DatePicker("", selection: $endTime, in: startTime..., displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
        }
    }

    private var summarySection: some View {
        let duration = max(0, Int(endTime.timeIntervalSince(startTime)))
        return Section("预览") {
            if let catId = selectedCategoryId, let cat = categories.first(where: { $0.id == catId }) {
                HStack {
                    Text("分类")
                    Spacer()
                    Text(cat.name).foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("开始")
                Spacer()
                Text(startTime.formatted(date: .numeric, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("结束")
                Spacer()
                Text(endTime.formatted(date: .numeric, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("时长")
                Spacer()
                Text(duration.prettyFormat)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        guard let catId = selectedCategoryId else { return }
        onSave(catId, startTime, endTime)
        dismiss()
    }
}

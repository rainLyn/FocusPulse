import SwiftUI
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  StatisticsView — 统计主页面
//  日饼图 + 时段明细 + 月历热力图 + 月份导航 + 数据清除
// ═════════════════════════════════════════════════════════════
struct StatisticsView: View {
    @State private var vm = StatisticsViewModel()
    @State private var clearSheetHeight: CGFloat = 440

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    pieChartSection
                    Divider().padding(.vertical, 12)
                    timelineSection
                    Divider().padding(.vertical, 12)
                    calendarSection
                }
            }
            .navigationTitle("统计")
            .toolbar { toolbarItems }
            .onAppear { vm.refresh() }
            .fileExporter(
                isPresented: Bindable(vm).showExportPicker,
                document: vm.exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "FocusPulse_Export"
            ) { _ in
                vm.exportDocument = nil
            }
            .sheet(isPresented: Bindable(vm).showMonthPicker) {
                monthPickerSheet
            }
            .sheet(isPresented: Bindable(vm).showClearDataSheet) {
                NavigationStack {
                    VStack {
                        DatePicker("", selection: Bindable(vm).clearCutoffDate,
                                   in: Date.distantPast...Date(), displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .labelsHidden()

                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.caption)
                            Text("该日期之前的所有记录将被永久清除")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)

                        Button("确认清除", role: .destructive) {
                            vm.prepareClearData()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                    .padding()
                    .background {
                        GeometryReader { proxy in
                            Color.clear.onAppear {
                                clearSheetHeight = proxy.size.height + 52
                            }
                        }
                    }
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.height(clearSheetHeight)])
            }
            .alert("确认清除数据", isPresented: Bindable(vm).showClearConfirmation) {
                Button("取消", role: .cancel) { vm.cancelClearData() }
                Button("确认清除", role: .destructive) { vm.confirmClearData() }
            } message: {
                if let date = vm.pendingClearDate {
                    Text("将从 \(date.formatted(date: .long, time: .omitted)) 起重新记录。\n该日期之前的 \(vm.pendingDeletionCount) 条记录将被永久删除，此操作不可撤销。")
                }
            }
            .alert("全部清除，重新开始", isPresented: Bindable(vm).showClearAllConfirmation) {
                Button("取消", role: .cancel) { vm.cancelClearAll() }
                Button("确认全部清除", role: .destructive) { vm.confirmClearAll() }
            } message: {
                Text("将永久删除全部 \(vm.pendingDeletionCount) 条专注记录。\n此操作不可撤销，确定要重新开始吗？")
            }
            .sheet(isPresented: Bindable(vm).showManageSheet) {
                SessionManageView(initialDate: vm.currentDate) {
                    vm.onManageDataChanged()
                }
            }
        }
    }

    // ── 饼图区 ──
    private var pieChartSection: some View {
        VStack(spacing: 12) {
            // 当前查看日期
            Text(vm.currentDate, format: .dateTime.year().month().day())
                .font(.headline)
                .frame(maxWidth: .infinity)

            // 总计时长
            if let breakdown = vm.dailyBreakdown {
                Text("总计: \(breakdown.totalSeconds.prettyFormat)")
                    .font(.title2.weight(.semibold))
            }

            // 饼图
            PieChartView(breakdown: vm.dailyBreakdown)
                .frame(height: 240)
                .padding(.horizontal, 16)

            // 分类明细
            if let breakdown = vm.dailyBreakdown, !breakdown.items.isEmpty {
                VStack(spacing: 8) {
                    ForEach(breakdown.items) { item in
                        HStack {
                            Circle()
                                .fill(ColorPalette.color(item.colorHex))
                                .frame(width: 10, height: 10)
                            Text(item.categoryName)
                                .font(.body)
                            Spacer()
                            Text(item.seconds.prettyFormat)
                                .font(.body.monospacedDigit())
                            Text("(\(Int(item.percentage * 100))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    // ── 时段明细 ──
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("时段明细")
                .font(.headline)
                .padding(.horizontal, 16)

            if vm.sessionTimeline.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    message: "当天暂无专注记录"
                )
                .frame(height: 100)
            } else {
                ForEach(Array(vm.sessionTimeline.enumerated()), id: \.offset) { _, item in
                    HStack {
                        Circle()
                            .fill(ColorPalette.color(item.2))
                            .frame(width: 8, height: 8)
                        Text(item.0.startTime.timeRange(to: item.0.endTime ?? item.0.startTime))
                            .font(.caption.monospacedDigit())
                        Text(item.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.0.durationSeconds.prettyFormat)
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // ── 月历热力图 + 月份导航 ──
    private var calendarSection: some View {
        VStack(spacing: 8) {
            // 月份切换（左右按键 + 点击弹窗）
            HStack {
                Button(action: {
                    HapticService.selection()
                    vm.goToPreviousMonth()
                }) {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(vm.currentDate, format: .dateTime.year().month())
                    .font(.headline)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        HapticService.selection()
                        let cal = Calendar.current
                        vm.pickerYear = cal.component(.year, from: vm.currentDate)
                        vm.pickerMonth = cal.component(.month, from: vm.currentDate)
                        vm.showMonthPicker = true
                    }

                Spacer()

                Button(action: {
                    HapticService.selection()
                    vm.goToNextMonth()
                }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(vm.isCurrentMonth)
            }
            .padding(.horizontal, 16)

            CalendarHeatmapView(
                month: vm.currentDate,
                heatmap: vm.monthlyHeatmap,
                selectedDate: vm.currentDate,
                onSelect: { date in vm.selectDate(date) }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    // ── Toolbar ──
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button { vm.prepareExport() } label: {
                    Label("导出 CSV", systemImage: "square.and.arrow.up")
                }
                Button { vm.showManageSheet = true } label: {
                    Label("管理记录", systemImage: "list.bullet.clipboard")
                }
                Divider()
                Button { vm.showClearDataSheet = true } label: {
                    Label("清除指定日期前数据", systemImage: "clock.arrow.circlepath")
                }
                Button(role: .destructive) { vm.prepareClearAll() } label: {
                    Label("全部清除，重新开始", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // ── 月份选择弹窗 ──
    private var monthPickerSheet: some View {
        let nowComps = Calendar.current.dateComponents([.year, .month], from: Date())
        return VStack(spacing: 0) {
            // 顶栏
            HStack {
                Button("取消") { vm.showMonthPicker = false }
                Spacer()
                Button("确定") { vm.confirmMonthPicker() }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // 年份选择
            HStack {
                Button { vm.pickerYear -= 1 } label: {
                    Image(systemName: "chevron.left")
                }
                Text("\(vm.pickerYear) 年")
                    .font(.title2.weight(.semibold))
                    .frame(width: 100)
                Button { vm.pickerYear += 1 } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.vertical, 12)

            // 月份网格
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(1...12, id: \.self) { m in
                    let isFuture = vm.pickerYear > nowComps.year! || (vm.pickerYear == nowComps.year! && m > nowComps.month!)
                    Text("\(m) 月")
                        .font(.body.weight(vm.pickerMonth == m ? .semibold : .regular))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(vm.pickerMonth == m ? Color.accentColor : Color(.systemGray6))
                        .foregroundStyle(vm.pickerMonth == m ? .white : (isFuture ? .gray.opacity(0.4) : .primary))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            if !isFuture { vm.pickerMonth = m }
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            Spacer()
        }
        .presentationDetents([.height(340)])
    }
}

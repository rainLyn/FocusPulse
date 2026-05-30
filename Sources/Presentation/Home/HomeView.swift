import SwiftUI
import FocusPulseCore

// ═════════════════════════════════════════════════════════════
//  HomeView — 主屏幕
//  分类选择 + 开始按钮 + 今日概览
// ═════════════════════════════════════════════════════════════
struct HomeView: View {
    @State private var vm = HomeViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.categories.isEmpty {
                    emptyCategories
                } else {
                    categorySection
                    startButton
                    todayPreview
                }
            }
            .navigationTitle("不要把梦想埋没")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .fullScreenCover(isPresented: Bindable(vm).showTimer) {
                ActiveTimerView(vm: vm)
            }
            .sheet(isPresented: Bindable(vm).showCategoryEditor) {
                CategoryEditView(
                    onSave: { name, hex in
                        vm.createCategory(name: name, colorHex: hex)
                    }
                )
            }
            .alert("检测到未结束的专注", isPresented: Bindable(vm).showInterruptionAlert) {
                Button("确认记录") { vm.acceptInterruption() }
                Button("丢弃", role: .destructive) { vm.discardInterruption() }
            } message: {
                if let s = vm.interruptionSession {
                    let elapsed = Int(Date().timeIntervalSince(s.startTime))
                    Text("上次专注在 \(elapsed.prettyFormat) 时意外中断，是否记录？")
                }
            }
            .alert("确认删除", isPresented: Bindable(vm).showDeleteConfirmation) {
                Button("删除", role: .destructive) { vm.confirmDelete() }
                Button("取消", role: .cancel) { vm.cancelDelete() }
            } message: {
                Text(vm.deleteConfirmationMessage)
            }
        }
        .onAppear { vm.initialize() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm.appDidBecomeActive() }
        }
    }

    // ── 分类列表 ──
    private var categorySection: some View {
        CategoryPickerView(
            categories: vm.categories,
            selectedId: Bindable(vm).selectedCategoryId,
            onDelete: { cat in vm.prepareToDelete(cat) }
        )
        .padding(.top, 12)
    }

    // ── 开始按钮 ──
    private var startButton: some View {
        Button(action: {
            HapticService.selection()
            vm.startFocus()
        }) {
            Label("开始专注", systemImage: "play.fill")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(canStart ? Color.accentColor : Color.gray.opacity(0.3))
                )
                .foregroundStyle(canStart ? .white : .secondary)
        }
        .pressAnimation()
        .disabled(!canStart)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var canStart: Bool {
        vm.selectedCategoryId != nil && !vm.timerEngine.isRunning
    }

    // ── 今日概览 ──
    private var todayPreview: some View {
        VStack(spacing: 4) {
            Divider().padding(.vertical, 12)

            if let breakdown = vm.dailyBreakdown {
                HStack(alignment: .center, spacing: 16) {
                    MiniPieChart(items: breakdown.items)
                        .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日总计")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(breakdown.totalSeconds.prettyFormat)
                            .font(.title2.weight(.bold))
                        if !breakdown.items.isEmpty {
                            Text("\(breakdown.items.count) 个分类")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
            } else {
                EmptyStateView(
                    icon: "chart.pie",
                    message: "今天还没有专注记录"
                )
                .frame(height: 120)
            }
        }
    }

    // ── 空状态 ──
    private var emptyCategories: some View {
        EmptyStateView(
            icon: "square.grid.2x2",
            message: "还没有分类，先创建一个吧",
            actionLabel: "创建分类",
            action: { vm.showCategoryEditor = true }
        )
    }

    // ── Toolbar ──
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                vm.showCategoryEditor = true
            } label: {
                Image(systemName: "plus")
            }
        }
    }
}

// ═════════════════════════════════════════════════════════════
//  MiniPieChart — 首页缩略饼图
//  仅展示颜色分段，不包含数据标签
// ═════════════════════════════════════════════════════════════
struct MiniPieChart: View {
    let items: [AggregationService.CategoryBreakdown]
    private let lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            if items.isEmpty {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)
            } else {
                let sorted = items.sorted { $0.percentage > $1.percentage }
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                    let start = sorted[0..<index].reduce(0.0) { $0 + $1.percentage }
                    PieSlice(
                        startAngle: .degrees(start * 360 - 90),
                        endAngle: .degrees((start + item.percentage) * 360 - 90)
                    )
                    .stroke(ColorPalette.color(item.colorHex), lineWidth: lineWidth)
                }
            }
        }
        .padding(4)
    }
}

struct PieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        Path { path in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = min(rect.width, rect.height) / 2
            path.addArc(center: center, radius: radius,
                       startAngle: startAngle, endAngle: endAngle,
                       clockwise: false)
        }
    }
}

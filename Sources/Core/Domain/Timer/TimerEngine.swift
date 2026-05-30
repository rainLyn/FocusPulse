import Foundation

// ═════════════════════════════════════════════════════════════
//  TimerEngine — 纯逻辑计时引擎
//  基于时间戳差（Date.now）而非 Timer 累加
//  不依赖 UIKit/SwiftUI，可独立单元测试
//
//  状态机:
//  [idle] ──start──> [running] ──stop──> [ended]
//     ↑                                      │
//     └────────── reset ──────────────────────┘
// ═════════════════════════════════════════════════════════════
@MainActor
public final class TimerEngine: ObservableObject {
    public enum State: Equatable {
        case idle
        case running(since: Date)
        case ended(FocusSession)

        public static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle): return true
            case (.running, .running): return true
            case (.ended, .ended): return true
            default: return false
            }
        }
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var elapsedSeconds: Int = 0

    private var categoryId: UUID?
    private var timer: Timer?
    private var sessionStart: Date?

    /// 是否正在专注中
    public var isRunning: Bool { if case .running = state { true } else { false } }

    /// 当前专注的分类 ID（仅在 running/ended 时有值）
    public var currentCategoryId: UUID? { categoryId }

    public init() {}

    // ──────────────────────────────────────────────
    //  Public API
    // ──────────────────────────────────────────────
    public func start(categoryId: UUID) {
        guard case .idle = state else { return }
        self.categoryId = categoryId
        sessionStart = Date()
        state = .running(since: sessionStart!)
        elapsedSeconds = 0

        startTicker()
    }

    public func stop() {
        guard case .running(let since) = state else { return }
        stopTicker()

        let end = Date()
        let duration = Int(end.timeIntervalSince(since))

        let session = FocusSession(
            categoryId: categoryId ?? UUID(),
            startTime: since,
            endTime: end,
            durationSeconds: duration
        )

        state = .ended(session)
        elapsedSeconds = duration
    }

    public func reset() {
        stopTicker()
        state = .idle
        elapsedSeconds = 0
        categoryId = nil
        sessionStart = nil
    }

    /// 从外部恢复一个未结束的 session
    public func restore(session: FocusSession, currentTime: Date = Date()) {
        guard session.endTime == nil else { return }
        categoryId = session.categoryId
        sessionStart = session.startTime
        state = .running(since: session.startTime)
        elapsedSeconds = Int(currentTime.timeIntervalSince(session.startTime))
        startTicker()
    }

    /// 计算实时 elapsed（外部调用，用于非 Timer 驱动的刷新）
    public func computeElapsed() -> Int {
        guard case .running(let since) = state else { return elapsedSeconds }
        return Int(Date().timeIntervalSince(since))
    }

    // ──────────────────────────────────────────────
    //  Private
    // ──────────────────────────────────────────────
    private func startTicker() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            let now = Date()
            Task { @MainActor [weak self] in
                guard let self, case .running(let since) = self.state else { return }
                self.elapsedSeconds = Int(now.timeIntervalSince(since))
            }
        }
    }

    private func stopTicker() {
        timer?.invalidate()
        timer = nil
    }
}

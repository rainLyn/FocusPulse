import Foundation
@preconcurrency import BackgroundTasks

// ═════════════════════════════════════════════════════════════
//  BackgroundTaskService — 后台任务调度（无状态命名空间）
//  封装 BGTaskScheduler 的注册/提交/过期处理
//  调用方只需提供 async 闭包，无需关心后台任务生命周期
// ═════════════════════════════════════════════════════════════
public enum BackgroundTaskService {
    public static let refreshTaskId = "com.focuspulse.refresh"

    /// 注册后台刷新处理器（在 didFinishLaunching 中调用一次）
    /// - Parameter onRefresh: 后台刷新时执行的异步任务
    public static func register(onRefresh: @escaping @Sendable () async -> Void) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskId,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            var completed = false
            let markDone: (Bool) -> Void = { success in
                guard !completed else { return }
                completed = true
                refreshTask.setTaskCompleted(success: success)
            }
            refreshTask.expirationHandler = { markDone(false) }
            Task {
                await onRefresh()
                markDone(true)
            }
        }
    }

    /// 提交后台刷新请求（在 app 进入后台时调用）
    public static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // 系统有 pending request 时忽略
        }
    }
}

import SwiftUI
import FocusPulseCore

// ═══════════════════════════════════════════════════════════════
//  FocusPulseApp — @main 入口
//  两 Tab 布局：专注 | 统计
//  集成通知中心与后台任务调度
// ═══════════════════════════════════════════════════════════════
@main
struct FocusPulseApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            TabView {
                HomeView()
                    .tabItem {
                        Label("专注", systemImage: "timer")
                    }

                StatisticsView()
                    .tabItem {
                        Label("统计", systemImage: "chart.pie")
                    }
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
                case .background:
                    BackgroundTaskService.schedule()
                default:
                    break
                }
            }
            .onOpenURL { url in
                FocusPulseApp.handleDeepLink(url)
            }
        }
    }
}

extension FocusPulseApp {
    /// 处理 Live Activity 点击跳转的深链
    static func handleDeepLink(_ url: URL) {
        guard url.scheme == "focuspulse", url.host == "timer" else { return }
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
    }
}

// ═══════════════════════════════════════════════════════════════
//  AppDelegate — 后台任务注册
//  必须在 didFinishLaunching 中调用，早于 SwiftUI 生命周期
// ═══════════════════════════════════════════════════════════════
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureBackgroundTasks()
        return true
    }

    private func configureBackgroundTasks() {
        BackgroundTaskService.register {
            await AggregationService().refreshDailySummary(for: Date())
        }
    }
}

extension Notification.Name {
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
}

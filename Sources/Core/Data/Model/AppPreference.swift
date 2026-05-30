import Foundation

// ═════════════════════════════════════════════════════════════
//  AppPreference — 应用偏好（UserDefaults 存储）
//  不经过 SwiftData，减少数据库写放大
// ═════════════════════════════════════════════════════════════
public struct AppPreference: Codable {
    public var hasCompletedOnboarding: Bool = false
    public var lastActiveDate: Date? = nil
    public var totalLifetimeSeconds: Int = 0
    public var longestStreak: Int = 0
}

public final class PreferenceStore {
    private let key = "com.focuspulse.preferences"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppPreference {
        guard let data = defaults.data(forKey: key) else { return AppPreference() }
        return (try? JSONDecoder().decode(AppPreference.self, from: data)) ?? AppPreference()
    }

    public func save(_ pref: AppPreference) {
        guard let data = try? JSONEncoder().encode(pref) else { return }
        defaults.set(data, forKey: key)
    }

    public func update(_ mutate: (inout AppPreference) -> Void) {
        var pref = load()
        mutate(&pref)
        save(pref)
    }
}

import Foundation

// ═════════════════════════════════════════════════════════════
//  StreakCalculator — 连续专注天数计算
//  纯函数，无副作用，可独立测试
// ═════════════════════════════════════════════════════════════
public enum StreakCalculator {
    /// 从 heatmap [date: seconds] 计算最长连续专注天数
    public static func longestStreak(from heatmap: [Date: Int]) -> Int {
        let activeDays = Set(heatmap.filter { $0.value > 0 }.keys)
        guard !activeDays.isEmpty else { return 0 }

        let sorted = activeDays.sorted()
        var longest = 1
        var current = 1

        for i in 1..<sorted.count {
            let diff = Calendar.current.dateComponents([.day], from: sorted[i - 1], to: sorted[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    /// 当前是否连续（从今天起连续往回数）
    public static func currentStreak(from heatmap: [Date: Int]) -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: Date())
        var streak = 0

        while true {
            let seconds = heatmap[day] ?? 0
            if seconds > 0 {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            } else {
                break
            }
        }

        return streak
    }
}

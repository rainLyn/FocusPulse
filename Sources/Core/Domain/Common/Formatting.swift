import Foundation

// ═════════════════════════════════════════════════════════════
//  Formatting — 时间格式化扩展
//  简洁、统一、无歧义
// ═════════════════════════════════════════════════════════════
extension Int {
    /// 秒数转可读格式: "5h 32m" (≥1h) / "32m" (≥1m) / "<1m"
    public var prettyFormat: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        }
        return "<1m"
    }

    /// hh:mm:ss 格式
    public var hmsFormat: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

extension Date {
    /// 格式化的时间段: "14:30-15:15"
    public func timeRange(to end: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return "\(fmt.string(from: self))-\(fmt.string(from: end))"
    }
}

import SwiftUI

// ═════════════════════════════════════════════════════════════
//  ColorPalette — 12 色固定调色板
//  饱和度 60-70%，明度 70-80%，防止选择瘫痪
// ═════════════════════════════════════════════════════════════
enum ColorPalette {
    static let all: [String] = [
        "4A90D9", // 蓝
        "7CBF6C", // 绿
        "E8A838", // 橙
        "E86E6E", // 红
        "9B59B6", // 紫
        "1ABC9C", // 青
        "F39C12", // 黄
        "E67E22", // 橙红
        "3498DB", // 天蓝
        "2ECC71", // 草绿
        "E74C3C", // 朱红
        "95A5A6", // 灰
    ]

    static let names: [String: String] = [
        "4A90D9": "蓝色", "7CBF6C": "绿色", "E8A838": "橙色",
        "E86E6E": "红色", "9B59B6": "紫色", "1ABC9C": "青色",
        "F39C12": "黄色", "E67E22": "橙红", "3498DB": "天蓝",
        "2ECC71": "草绿", "E74C3C": "朱红", "95A5A6": "灰色",
    ]

    static func color(_ hex: String) -> Color {
        guard hex.count == 6, let val = Int(hex, radix: 16) else { return .gray }
        let r = Double((val >> 16) & 0xFF) / 255
        let g = Double((val >> 8) & 0xFF) / 255
        let b = Double(val & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}

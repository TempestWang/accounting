import SwiftUI

/// 分类配色：常用分类有固定颜色，其余按名称散列
enum ColorPalette {
    static func color(for name: String) -> Color {
        switch name {
        case "餐饮": return .orange
        case "交通": return .blue
        case "购物": return .pink
        case "居住": return .brown
        case "娱乐": return .purple
        case "医疗": return .red
        case "教育": return .teal
        case "工资": return .green
        case "奖金": return .yellow
        case "理财": return .indigo
        default:
            // 自实现 djb2 稳定哈希：同一分类跨启动颜色一致；
            // 使用 UInt 溢出包装运算，避免 abs(Int.min) 崩溃风险
            var hash: UInt = 5381
            for byte in name.utf8 {
                hash = (hash &* 33) &+ UInt(byte)
            }
            let palette: [Color] = [.red, .orange, .yellow, .green, .teal, .blue, .indigo, .purple, .pink, .brown, .mint, .cyan]
            return palette[Int(hash % UInt(palette.count))]
        }
    }
}

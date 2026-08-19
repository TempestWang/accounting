import SwiftUI

/// 分类配色：参考设计稿精选清新明快的色板，保持高级感。
/// 常用分类固定颜色，其余按名称稳定散列到同一色板。
/// UI优化：根据设计稿调整配色和样式
enum ColorPalette {
    static func color(for name: String) -> Color {
        switch name {
        case "餐饮": return Color(red: 1.0, green: 0.45, blue: 0.35)    // 活力橙红
        case "交通": return Color(red: 0.30, green: 0.60, blue: 0.92)   // 清爽蓝
        case "购物": return Color(red: 0.95, green: 0.40, blue: 0.55)   // 玫瑰粉
        case "居住": return Color(red: 0.55, green: 0.78, blue: 0.45)   // 自然绿
        case "娱乐": return Color(red: 0.60, green: 0.50, blue: 0.92)   // 梦幻紫
        case "医疗": return Color(red: 0.92, green: 0.35, blue: 0.35)   // 警示红
        case "教育": return Color(red: 0.20, green: 0.72, blue: 0.65)   // 清新青
        case "工资": return Color(red: 0.20, green: 0.70, blue: 0.50)   // 收入绿
        case "奖金": return Color(red: 1.0, green: 0.70, blue: 0.20)    // 金色
        case "理财": return Color(red: 0.35, green: 0.50, blue: 0.90)   // 靛蓝
        default:
            // 自实现 djb2 稳定哈希：同一分类跨启动颜色一致；
            // 使用 UInt 溢出包装运算，避免 abs(Int.min) 崩溃风险
            var hash: UInt = 5381
            for byte in name.utf8 {
                hash = (hash &* 33) &+ UInt(byte)
            }
            let palette: [Color] = [
                Color(red: 1.0, green: 0.45, blue: 0.35),
                Color(red: 0.30, green: 0.60, blue: 0.92),
                Color(red: 0.95, green: 0.40, blue: 0.55),
                Color(red: 0.55, green: 0.78, blue: 0.45),
                Color(red: 0.60, green: 0.50, blue: 0.92),
                Color(red: 0.92, green: 0.35, blue: 0.35),
                Color(red: 0.20, green: 0.72, blue: 0.65),
                Color(red: 0.20, green: 0.70, blue: 0.50),
                Color(red: 1.0, green: 0.70, blue: 0.20),
                Color(red: 0.35, green: 0.50, blue: 0.90),
                Color(red: 0.90, green: 0.45, blue: 0.70)
            ]
            return palette[Int(hash % UInt(palette.count))]
        }
    }
}

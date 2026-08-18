import SwiftUI
import UIKit

/// 全局主题（仿「鲨鱼记账」风格）：鲨鱼蓝主色、浅灰底、白色圆角卡片。
/// 颜色语义：主色 → 核心操作 / 重点数据；绿色 → 收入 / 正常；红色 → 支出 / 超支；
/// 橙色 → 警告（接近预算）；青绿 → 预算健康状态；灰色 → 辅助信息。
enum AppTheme {
    /// 主色调：鲨鱼蓝（深色模式下自动提亮，保证对比度）
    static let primary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.63, blue: 0.97, alpha: 1)
            : UIColor(red: 0.13, green: 0.55, blue: 0.96, alpha: 1)
    })

    /// 页面背景（浅灰）
    static let background = Color(.systemGroupedBackground)

    /// 卡片背景（白 / 深色系统黑）
    static let cardBackground = Color(.systemBackground)

    /// 支出红 / 收入绿
    static let expense = Color(red: 0.94, green: 0.27, blue: 0.29)
    static let income = Color(red: 0.22, green: 0.70, blue: 0.44)

    /// 警告橙（接近预算）
    static let warning = Color(red: 1.00, green: 0.69, blue: 0.13)

    /// 预算健康色（青绿）：正常状态下的进度与核心数字
    static let budgetHealthy = Color(red: 0.13, green: 0.78, blue: 0.65)

    /// 预算页专用背景：浅灰绿 #F5F8F7（深色模式自动切换为深色）
    static let budgetBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.11, blue: 0.11, alpha: 1)
            : UIColor(red: 0.96, green: 0.97, blue: 0.97, alpha: 1)
    })

    /// 预算主卡青绿渐变（克制）：#22C7A5 → 稍浅 #5CD8C0
    static let budgetGradient = LinearGradient(
        colors: [
            Color(red: 0.13, green: 0.78, blue: 0.65),
            Color(red: 0.36, green: 0.85, blue: 0.75),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 首页总览卡片的蓝色渐变
    static let gradient = LinearGradient(
        colors: [
            Color(red: 0.13, green: 0.55, blue: 0.96),
            Color(red: 0.34, green: 0.66, blue: 0.98),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// 间距规范（4 / 8 的倍数）
enum AppSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
}

/// 圆角规范
enum AppRadius {
    static let input: CGFloat = 12
    static let card: CGFloat = 16
    static let heroCard: CGFloat = 20
    static let xlarge: CGFloat = 24
    /// 胶囊按钮
    static let capsule: CGFloat = 999
}

/// 白色圆角卡片样式
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .fill(AppTheme.cardBackground)
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
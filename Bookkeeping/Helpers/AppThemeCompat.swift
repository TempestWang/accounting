import SwiftUI
import UIKit

/// 全局主题兼容层（旧页面引用统一收敛到 DesignSystem）。
/// 注意：因 Theme/AppTheme.swift 引入新的主题模型 AppTheme，
/// 本兼容枚举更名为 AppThemeCompat，避免名称冲突；语义不变。
/// - 所有颜色语义最终指向 DSColor（主题驱动，自适应 Light / Dark）；
/// - AppSpacing / AppRadius 由 DSpace / DRadius 提供；
/// - 旧的渐变常量已移除（新视觉不依赖大面积渐变）。
/// UI优化：根据设计稿添加新颜色
enum AppThemeCompat {
    /// 品牌主色 — UI优化：紫色
    static let primary = DSColor.primary
    /// 页面背景
    static let background = DSColor.background
    /// 卡片背景
    static let cardBackground = DSColor.cardBackground
    /// 次级填充
    static let secondaryFill = DSColor.secondaryFill
    /// 发丝描边
    static let hairline = DSColor.hairline
    /// 支出暖珊瑚
    static let expense = DSColor.expense
    /// 收入草木绿
    static let income = DSColor.income
    /// 警告琥珀
    static let warning = DSColor.warning
    /// 预算健康色（柔和水鸭青）
    static let budgetHealthy = DSColor.healthy
    /// 预算页背景（与全局背景统一，保持呼吸感）
    static let budgetBackground = DSColor.background
    /// 深色英雄卡背景 — UI优化
    static let heroCardDark = DSColor.heroCardDark
}

/// 间距规范（4 / 8 的倍数）
enum AppSpacing {
    static let xs: CGFloat = DSpace.xs
    static let s: CGFloat = DSpace.sm
    static let m: CGFloat = DSpace.md
    static let l: CGFloat = DSpace.lg
    static let xl: CGFloat = DSpace.xl
    static let xxl: CGFloat = DSpace.xxl
    static let xxxl: CGFloat = DSpace.xxxl
}

/// 圆角规范
enum AppRadius {
    static let input: CGFloat = DRadius.medium
    static let card: CGFloat = DRadius.card
    static let heroCard: CGFloat = DRadius.hero
    static let xlarge: CGFloat = DRadius.hero
    static let capsule: CGFloat = DRadius.capsule
}

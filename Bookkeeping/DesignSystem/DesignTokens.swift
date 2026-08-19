import SwiftUI
import UIKit

// MARK: - 色彩体系（主题驱动 · 自适应 Light / Dark）

/// 高级化设计系统 · 色彩令牌
///
/// 设计原则：
/// - 所有颜色都来自 `ThemeManager.shared.colors`（当前主题 × 当前外观），
///   底层是 `UIColor` 动态 Provider，随系统深浅色自动切换；
/// - 主题系统（`Bookkeeping/Theme/`）负责定义 8 套主题的完整色板，
///   本枚举保持原有静态 API 不变，供既有页面零改动地接入主题；
/// - 结构层（背景 / 卡片 / 分割线）交给中性推导色，彩色只用于数据与状态。
enum DSColor {
    /// 品牌主色（随主题变化）：文字强调 / 图表 / 软底 icon
    static var primary: Color { ThemeManager.shared.colors.primary }
    /// 品牌实心填充（主按钮 / 悬浮按钮）
    static var primaryFill: Color { ThemeManager.shared.colors.primary }

    /// 收入：柔和草木绿（与主题无关的全局语义色）
    static var income: Color { ThemeManager.shared.colors.income }
    /// 支出：暖珊瑚
    static var expense: Color { ThemeManager.shared.colors.expense }
    /// 警告：琥珀
    static var warning: Color { ThemeManager.shared.colors.warning }
    /// 健康 / 正常语义：柔和水鸭青
    static var healthy: Color { ThemeManager.shared.colors.healthy }

    /// 页面背景（随主题渐变基调）
    static var background: Color { ThemeManager.shared.colors.background }
    /// 卡片背景
    static var cardBackground: Color { ThemeManager.shared.colors.card }
    /// 次级填充：图标底、次级按钮、chip
    static var secondaryFill: Color { ThemeManager.shared.colors.secondaryFill }

    /// 深色英雄卡背景（首页总览卡片，随主题色系变化）
    static var heroCardDark: Color { ThemeManager.shared.colors.heroCard }

    /// 品牌渐变起始色（主按钮 / 悬浮按钮 / 品牌渐变）
    static var gradientStart: Color { ThemeManager.shared.colors.gradientStart }
    /// 品牌渐变结束色
    static var gradientEnd: Color { ThemeManager.shared.colors.gradientEnd }

    /// 旧名兼容：品牌渐变起始色（主按钮 / 悬浮按钮 / 品牌渐变）
    static var purpleGradientStart: Color { gradientStart }
    /// 旧名兼容：品牌渐变结束色
    static var purpleGradientEnd: Color { gradientEnd }

    /// 主按钮 / 品牌填充上的文字色（默认白色；Minimal 深色模式为黑色）
    static var buttonText: Color { ThemeManager.shared.colors.buttonText }

    /// 发丝级描边 / 分割线
    static var hairline: Color { ThemeManager.shared.colors.hairline }
    /// 进度条轨道
    static var track: Color { ThemeManager.shared.colors.track }
}

// MARK: - 字体层级

/// 统一 SF Pro（系统字体），金额统一使用 SF Pro Rounded，强化「钱」的识别度。
enum Typography {
    /// 页面大标题（Large Title）
    static let largeTitle = Font.system(size: 32, weight: .bold)
    /// 区块标题（Title）
    static let title2 = Font.system(size: 22, weight: .bold)
    /// 标题级（Headline）
    static let headline = Font.system(size: 17, weight: .semibold)
    /// 正文（Body）
    static let body = Font.system(size: 16, weight: .regular)
    /// 次级正文（Subheadline）
    static let subheadline = Font.system(size: 14, weight: .medium)
    /// 辅助（Caption）
    static let caption = Font.system(size: 12, weight: .regular)
    /// 说明（Caption2）
    static let caption2 = Font.system(size: 11, weight: .regular)

    /// 大金额：页面视觉中心
    static let moneyHero = Font.system(size: 40, weight: .bold, design: .rounded)
    /// 卡片主数值
    static let moneyTitle = Font.system(size: 26, weight: .bold, design: .rounded)
    /// 列表 / 行内金额
    static let moneyBody = Font.system(size: 17, weight: .semibold, design: .rounded)
}

// MARK: - 间距规范（4/8 的倍数）

enum DSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 32
    /// 页面左右留白
    static let page: CGFloat = 16
    /// 区块之间呼吸感
    static let section: CGFloat = 24
}

// MARK: - 圆角规范

enum DRadius {
    /// 小控件（小图标底）
    static let small: CGFloat = 10
    /// 输入框 / 次级控件
    static let medium: CGFloat = 14
    /// 标准卡片
    static let card: CGFloat = 20
    /// 大卡（总览 / 主操作）
    static let hero: CGFloat = 24
    /// 胶囊按钮
    static let capsule: CGFloat = 999
}
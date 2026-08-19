import SwiftUI
import UIKit

// MARK: - 原始颜色值

/// 一个 8-bit RGB 颜色（附带透明度），主题数据源的最小单位。
/// 同时能生成 SwiftUI `Color` 与 `UIColor`，保证预览与系统渲染一致。
struct RGBColor: Equatable, Sendable {
    var r: Double
    var g: Double
    var b: Double
    var alpha: Double

    init(_ r: Double, _ g: Double, _ b: Double, alpha: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.alpha = alpha
    }

    /// 直接以十六进制定义，例如 `RGBColor(0x6B5CE7)`。
    init(_ hex: UInt32, alpha: Double = 1) {
        self.r = Double((hex >> 16) & 0xFF) / 255
        self.g = Double((hex >> 8) & 0xFF) / 255
        self.b = Double(hex & 0xFF) / 255
        self.alpha = alpha
    }

    var color: Color { Color(red: r, green: g, blue: b).opacity(alpha) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: alpha) }
}

// MARK: - 主题调色板（单一明暗外观下的原始色）

/// 一个主题在单一外观（浅色或深色）下的核心色板。
///
/// 语义约定：
/// - `primary`     主色（品牌色，用于图标、强调、选中态）
/// - `secondary`   辅助色（与主色搭配的互补色，用于渐变与次级强调）
/// - `gradient*`   渐变起止色（主按钮、总览卡光晕、品牌渐变）
/// - `background`  页面背景
/// - `card`        卡片背景
/// - `heroCard`    首页总览等「深色英雄卡」背景（所有主题保持深色系，文字用白色）
/// - `heroGlow`    英雄卡上的品牌光晕色
/// - `buttonText`  主按钮上的文字色（默认白色；Minimal 深色模式为黑色）
///
/// 文字色 / 分割线 / 次级填充等中性层不在此定义，由 `ThemeColors` 统一推导，
/// 保证任何主题下都有正确对比度。
struct ThemePalette: Equatable, Sendable {
    var primary: RGBColor
    var secondary: RGBColor
    var gradientStart: RGBColor
    var gradientEnd: RGBColor
    var background: RGBColor
    var card: RGBColor
    var heroCard: RGBColor
    var heroGlow: RGBColor
    var buttonText: RGBColor

    init(primary: RGBColor, secondary: RGBColor, gradientStart: RGBColor,
         gradientEnd: RGBColor, background: RGBColor, card: RGBColor,
         heroCard: RGBColor, heroGlow: RGBColor,
         buttonText: RGBColor = RGBColor(0xFFFFFF)) {
        self.primary = primary
        self.secondary = secondary
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
        self.background = background
        self.card = card
        self.heroCard = heroCard
        self.heroGlow = heroGlow
        self.buttonText = buttonText
    }
}

// MARK: - 主题按钮样式

/// 主题级按钮形态：实心单色（Apple 式）或品牌渐变（多彩主题式）。
enum ThemeButtonStyle: Equatable, Sendable {
    /// 实心主色按钮（Minimal / Apple）
    case solid
    /// 主色 → 渐变结束色（Purple / Sunset / Gold 等）
    case gradient

    /// 按钮填充渐变（实心时退化为单色渐变，便于复用同一绘制路径）
    var gradientColors: [Color] {
        switch self {
        case .solid:
            return [DSColor.primary, DSColor.primary]
        case .gradient:
            return [DSColor.primary, DSColor.gradientEnd]
        }
    }
}

// MARK: - 解析后的主题色（随系统深浅色自动切换）

/// 解析后的主题色：全部为**动态颜色**（基于 `UIColor` 动态 Provider），
/// 在渲染时根据当前有效外观（系统深浅色 × App 外观设置）自动选择对应色板。
///
/// 使用方式：`ThemeManager.shared.colors` 取当前主题解析结果；视图内
/// 优先通过 `@EnvironmentObject var theme: ThemeManager` 读取 `theme.colors`，
/// 这样主题切换时该视图会自动刷新（DSColor 的静态别名也能直接用于既有代码）。
struct ThemeColors: Equatable {
    // 品牌层
    let primary: Color
    let secondary: Color
    let gradientStart: Color
    let gradientEnd: Color

    // 结构层
    let background: Color
    let card: Color
    let secondaryFill: Color
    let hairline: Color
    let track: Color

    // 文字层（中性，任何主题下保证对比度）
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    // 图标层（默认跟随主色）
    let iconColor: Color

    // 英雄卡层
    let heroCard: Color
    let heroGlow: Color

    // 按钮文字层（主色填充 / 渐变填充上的文字色）
    let buttonText: Color

    // 语义层（收入 / 支出 / 警告 / 健康，全局统一，不随主题漂移）
    let income: Color
    let expense: Color
    let warning: Color
    let healthy: Color

    /// 主按钮使用的品牌渐变（由 ThemeButtonStyle 决定实心或渐变）
    var buttonGradient: [Color] { [primary, gradientEnd] }

    /// 由「浅色 + 深色」两套原始色板构建动态主题色
    static func resolve(light: ThemePalette, dark: ThemePalette) -> ThemeColors {
        func dyn(_ lightKey: KeyPath<ThemePalette, RGBColor>,
                 _ darkKey: KeyPath<ThemePalette, RGBColor>) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? dark[keyPath: darkKey].uiColor
                    : light[keyPath: lightKey].uiColor
            })
        }

        // 中性层：浅色模式用黑底推导，深色模式用白底推导，
        // 保证任何主题下对比度正确
        func neutral(_ lightOpacity: Double, _ darkOpacity: Double) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.white.withAlphaComponent(darkOpacity)
                    : UIColor.black.withAlphaComponent(lightOpacity)
            })
        }

        let semanticLight: [RGBColor] = [
            RGBColor(0x2B946B),  // income
            RGBColor(0xD95A47),  // expense
            RGBColor(0xD99E33),  // warning
            RGBColor(0x1FAD94)   // healthy
        ]
        let semanticDark: [RGBColor] = [
            RGBColor(0x73D1A3),
            RGBColor(0xF58C7A),
            RGBColor(0xF2BC61),
            RGBColor(0x6BD9BF)
        ]

        return ThemeColors(
            primary: dyn(\.primary, \.primary),
            secondary: dyn(\.secondary, \.secondary),
            gradientStart: dyn(\.gradientStart, \.gradientStart),
            gradientEnd: dyn(\.gradientEnd, \.gradientEnd),
            background: dyn(\.background, \.background),
            card: dyn(\.card, \.card),
            secondaryFill: neutral(0.06, 0.10),
            hairline: neutral(0.06, 0.12),
            track: neutral(0.08, 0.14),
            textPrimary: neutral(0.86, 0.92),
            textSecondary: neutral(0.55, 0.62),
            textTertiary: neutral(0.34, 0.40),
            iconColor: dyn(\.primary, \.primary),
            heroCard: dyn(\.heroCard, \.heroCard),
            heroGlow: dyn(\.heroGlow, \.heroGlow),
            buttonText: dyn(\.buttonText, \.buttonText),
            income: Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? semanticDark[0].uiColor : semanticLight[0].uiColor
            }),
            expense: Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? semanticDark[1].uiColor : semanticLight[1].uiColor
            }),
            warning: Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? semanticDark[2].uiColor : semanticLight[2].uiColor
            }),
            healthy: Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? semanticDark[3].uiColor : semanticLight[3].uiColor
            })
        )
    }
}
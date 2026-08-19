import SwiftUI

// MARK: - 主题模型

/// 一套 App 主题：身份信息 + 深浅两套色板 + 按钮形态。
///
/// 每一套主题都同时提供 Light / Dark 两套色板，随系统深浅色
/// （或 App 内「外观」设置）自动切换，满足「支持深浅色模式」的要求。
struct AppTheme: Identifiable, Equatable {
    /// 稳定标识（持久化到 UserDefaults）
    let id: String
    /// 主题名称（中文展示）
    let name: String
    /// 一句话风格说明
    let subtitle: String
    /// 预览 Symbol（主题卡片角落的隐喻图标）
    let symbolName: String
    /// 按钮形态：实心 / 渐变
    let buttonStyle: ThemeButtonStyle
    /// 浅色色板
    let light: ThemePalette
    /// 深色色板
    let dark: ThemePalette

    /// 解析后的动态色（渲染时按有效外观自动选择 Light / Dark）
    var resolvedColors: ThemeColors {
        ThemeColors.resolve(light: light, dark: dark)
    }

    /// 内置全部主题（按展示顺序）
    static let all: [AppTheme] = [
        .apple, .midnight, .purpleDream, .ocean,
        .forest, .sunset, .minimal, .goldWealth
    ]

    /// 按 id 查找；找不到时回退到 Apple 默认
    static func theme(for id: String) -> AppTheme? {
        all.first { $0.id == id }
    }

    /// 默认主题
    static let apple = AppTheme(
        id: "apple",
        name: "Apple 默认",
        subtitle: "简洁白色 · SF 风格 · 蓝色强调",
        symbolName: "apple.logo",
        buttonStyle: .solid,
        light: ThemePalette(
            primary: RGBColor(0x007AFF),
            secondary: RGBColor(0x5E5CE6),
            gradientStart: RGBColor(0x007AFF),
            gradientEnd: RGBColor(0x5E5CE6),
            background: RGBColor(0xF2F2F7),
            card: RGBColor(0xFFFFFF),
            heroCard: RGBColor(0x1C1C1E),
            heroGlow: RGBColor(0x0A84FF)
        ),
        dark: ThemePalette(
            primary: RGBColor(0x0A84FF),
            secondary: RGBColor(0x6E6AFF),
            gradientStart: RGBColor(0x0A84FF),
            gradientEnd: RGBColor(0x6E6AFF),
            background: RGBColor(0x000000),
            card: RGBColor(0x1C1C1E),
            heroCard: RGBColor(0x2C2C2E),
            heroGlow: RGBColor(0x0A84FF)
        )
    )

    /// Midnight 夜空：深黑背景 + 深蓝渐变，高级金融 App 氛围
    static let midnight = AppTheme(
        id: "midnight",
        name: "Midnight 夜空",
        subtitle: "深邃黑蓝 · 星空渐变 · 稳重克制",
        symbolName: "moon.stars.fill",
        buttonStyle: .gradient,
        light: ThemePalette(
            primary: RGBColor(0x3355E9),
            secondary: RGBColor(0x3FC1F0),
            gradientStart: RGBColor(0x4F6DF5),
            gradientEnd: RGBColor(0x1B2C6B),
            background: RGBColor(0xECEFF8),
            card: RGBColor(0xFFFFFF),
            heroCard: RGBColor(0x14204D),
            heroGlow: RGBColor(0x4F6DF5)
        ),
        dark: ThemePalette(
            primary: RGBColor(0x7C9BFF),
            secondary: RGBColor(0x5AD4FF),
            gradientStart: RGBColor(0x3A55C9),
            gradientEnd: RGBColor(0x0E1636),
            background: RGBColor(0x06070E),
            card: RGBColor(0x0F1420),
            heroCard: RGBColor(0x0A1028),
            heroGlow: RGBColor(0x3A55C9)
        )
    )

    /// Purple Dream 紫境：紫色渐变，科技感，高端 App Store 风格
    static let purpleDream = AppTheme(
        id: "purple",
        name: "Purple Dream 紫境",
        subtitle: "紫罗兰渐变 · 科技感 · 高端气质",
        symbolName: "sparkles",
        buttonStyle: .gradient,
        light: ThemePalette(
            primary: RGBColor(0x6B5CE7),
            secondary: RGBColor(0xC56CF0),
            gradientStart: RGBColor(0x6B5CE7),
            gradientEnd: RGBColor(0x8C61D1),
            background: RGBColor(0xF6F4FE),
            card: RGBColor(0xFFFFFF),
            heroCard: RGBColor(0x2E2C40),
            heroGlow: RGBColor(0x6B5CE7)
        ),
        dark: ThemePalette(
            primary: RGBColor(0xA694FF),
            secondary: RGBColor(0xD98CFF),
            gradientStart: RGBColor(0x8070F0),
            gradientEnd: RGBColor(0xB38CE0),
            background: RGBColor(0x13111F),
            card: RGBColor(0x1D1A2E),
            heroCard: RGBColor(0x231F38),
            heroGlow: RGBColor(0x8070F0)
        )
    )

    /// Ocean 海洋：蓝绿色，清爽，年轻化
    static let ocean = AppTheme(
        id: "ocean",
        name: "Ocean 海洋",
        subtitle: "海蓝与青绿 · 清爽通透 · 年轻活力",
        symbolName: "water.waves",
        buttonStyle: .gradient,
        light: ThemePalette(
            primary: RGBColor(0x0087C9),
            secondary: RGBColor(0x00B8A8),
            gradientStart: RGBColor(0x00A8E8),
            gradientEnd: RGBColor(0x0072A3),
            background: RGBColor(0xEFF8FB),
            card: RGBColor(0xFFFFFF),
            heroCard: RGBColor(0x0A3A4A),
            heroGlow: RGBColor(0x00A8E8)
        ),
        dark: ThemePalette(
            primary: RGBColor(0x4DC3F4),
            secondary: RGBColor(0x3FE0C9),
            gradientStart: RGBColor(0x00BFE6),
            gradientEnd: RGBColor(0x01608C),
            background: RGBColor(0x05171D),
            card: RGBColor(0x0C242C),
            heroCard: RGBColor(0x08222B),
            heroGlow: RGBColor(0x00BFE6)
        )
    )

    /// Forest 森林：绿色系，自然，健康财务感
    static let forest = AppTheme(
        id: "forest",
        name: "Forest 森林",
        subtitle: "自然绿 · 森林呼吸 · 健康财务",
        symbolName: "leaf.fill",
        buttonStyle: .gradient,
        light: ThemePalette(
            primary: RGBColor(0x2E9E5B),
            secondary: RGBColor(0x57B67C),
            gradientStart: RGBColor(0x34C759),
            gradientEnd: RGBColor(0x1F7A45),
            background: RGBColor(0xF1F7F2),
            card: RGBColor(0xFFFFFF),
            heroCard: RGBColor(0x12331F),
            heroGlow: RGBColor(0x34C759)
        ),
        dark: ThemePalette(
            primary: RGBColor(0x5BD288),
            secondary: RGBColor(0x7CD6A4),
            gradientStart: RGBColor(0x2FBF71),
            gradientEnd: RGBColor(0x14532D),
            background: RGBColor(0x081108),
            card: RGBColor(0x102017),
            heroCard: RGBColor(0x0B2416),
            heroGlow: RGBColor(0x2FBF71)
        )
    )

    /// Sunset 日落：橙红渐变，温暖，活力
    static let sunset = AppTheme(
        id: "sunset",
        name: "Sunset 日落",
        subtitle: "橙红渐变 · 温暖治愈 · 活力四射",
        symbolName: "sun.max.fill",
        buttonStyle: .gradient,
        light: ThemePalette(
            primary: RGBColor(0xFF6B35),
            secondary: RGBColor(0xFF3D5A),
            gradientStart: RGBColor(0xFF8A3D),
            gradientEnd: RGBColor(0xFF3D5A),
            background: RGBColor(0xFFF5EF),
            card: RGBColor(0xFFFFFF),
            heroCard: RGBColor(0x46200F),
            heroGlow: RGBColor(0xFF6B35)
        ),
        dark: ThemePalette(
            primary: RGBColor(0xFF8A5C),
            secondary: RGBColor(0xFF5C77),
            gradientStart: RGBColor(0xF2701D),
            gradientEnd: RGBColor(0xE63946),
            background: RGBColor(0x1C0F0C),
            card: RGBColor(0x2B1712),
            heroCard: RGBColor(0x331611),
            heroGlow: RGBColor(0xF2701D)
        )
    )

    /// Minimal 极简：黑白灰，Notion / Things 风格
    static let minimal = AppTheme(
        id: "minimal",
        name: "Minimal 极简",
        subtitle: "黑白灰 · 留白秩序 · 专注本质",
        symbolName: "circle.lefthalf.filled",
        buttonStyle: .solid,
        light: ThemePalette(
            primary: RGBColor(0x111111),
            secondary: RGBColor(0x6E6E73),
            gradientStart: RGBColor(0x111111),
            gradientEnd: RGBColor(0x3A3A3C),
            background: RGBColor(0xFFFFFF),
            card: RGBColor(0xF5F5F7),
            heroCard: RGBColor(0x0A0A0A),
            heroGlow: RGBColor(0x3A3A3C)
        ),
        dark: ThemePalette(
            primary: RGBColor(0xF5F5F7),
            secondary: RGBColor(0x98989D),
            gradientStart: RGBColor(0x1C1C1E),
            gradientEnd: RGBColor(0xF5F5F7),
            background: RGBColor(0x000000),
            card: RGBColor(0x1C1C1E),
            heroCard: RGBColor(0x161616),
            heroGlow: RGBColor(0x3A3A3C),
            buttonText: RGBColor(0x000000)
        )
    )

    /// Gold Wealth 财富：黑金配色，高端金融感
    static let goldWealth = AppTheme(
        id: "gold",
        name: "Gold Wealth 财富",
        subtitle: "黑金配色 · 鎏金质感 · 高端金融",
        symbolName: "crown.fill",
        buttonStyle: .gradient,
        light: ThemePalette(
            primary: RGBColor(0xB8860B),
            secondary: RGBColor(0xA67C00),
            gradientStart: RGBColor(0xD4AF37),
            gradientEnd: RGBColor(0x8C6D1F),
            background: RGBColor(0xFBF9F3),
            card: RGBColor(0xFFFFFF),
            heroCard: RGBColor(0x2A2008),
            heroGlow: RGBColor(0xD4AF37)
        ),
        dark: ThemePalette(
            primary: RGBColor(0xF2C94C),
            secondary: RGBColor(0xFFD97A),
            gradientStart: RGBColor(0xF2C94C),
            gradientEnd: RGBColor(0xB8860B),
            background: RGBColor(0x0D0B06),
            card: RGBColor(0x1A150B),
            heroCard: RGBColor(0x1A1406),
            heroGlow: RGBColor(0xF2C94C)
        )
    )
}
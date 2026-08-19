import SwiftUI

// MARK: - 迷你 App 首页预览

/// 非交互的「App 首页」模拟图，完全使用传入的 `ThemeColors` 渲染，
/// 供主题选择页做实时预览（大卡）与每套主题卡片（小卡）使用。
///
/// 设计尺寸为 172×240，`compact = true` 时等比缩小到 55% 用作卡片缩略图。
struct ThemeAppPreview: View {
    let colors: ThemeColors
    var compact: Bool = false

    private let designWidth: CGFloat = 172
    private let designHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            heroCard
            categoryRow
            transactionRows
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(colors.background)
        .frame(width: designWidth, height: designHeight)
        .scaleEffect(compact ? 0.55 : 1, anchor: .topLeading)
        .frame(width: designWidth * (compact ? 0.55 : 1),
               height: designHeight * (compact ? 0.55 : 1),
               alignment: .topLeading)
    }

    // 总结算卡（模拟首页英雄卡）
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("8月账单")
                    .font(.system(size: 9, weight: .medium))
                Spacer()
                Text("+6.2%")
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.18)))
                    .foregroundStyle(Color.white)
            }
            .foregroundStyle(Color.white.opacity(0.7))

            Text("¥12,680.00")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)

            HStack(spacing: 12) {
                Text("收入 ¥15,300").font(.system(size: 8))
                Text("支出 ¥2,620").font(.system(size: 8))
                Spacer()
                Text("管理")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.2)))
            }
            .foregroundStyle(Color.white.opacity(0.6))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroFill)
    }

    private var heroFill: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(colors.heroCard)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            colors.gradientStart.opacity(0.55),
                            colors.gradientEnd.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // 快捷记账图标排
    private var categoryRow: some View {
        HStack(spacing: 6) {
            iconSquare(colors.primary, symbol: "fork.knife")
            iconSquare(colors.secondary, symbol: "car.fill")
            iconSquare(colors.gradientStart, symbol: "bag.fill")
            iconSquare(colors.gradientEnd, symbol: "gamecontroller.fill")
        }
    }

    private func iconSquare(_ color: Color, symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(color.opacity(0.16))
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(color)
            )
            .frame(width: 24, height: 24)
    }

    // 最近流水两行
    private var transactionRows: some View {
        VStack(spacing: 6) {
            transactionRow(
                symbol: "cup.and.saucer.fill",
                name: "咖啡",
                amount: "-¥28.00",
                amountColor: colors.expense
            )
            transactionRow(
                symbol: "briefcase.fill",
                name: "工资",
                amount: "+¥8,000.00",
                amountColor: colors.income
            )
        }
    }

    private func transactionRow(symbol: String, name: String,
                                amount: String, amountColor: Color) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(colors.secondaryFill)
                .frame(width: 20, height: 20)
                .overlay(
                    Image(systemName: symbol)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(colors.iconColor)
                )
            Text(name)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(colors.textPrimary)
            Spacer()
            Text(amount)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(amountColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(colors.card)
        )
    }
}

// MARK: - 主题色点（卡片上的色彩展示）

/// 展示主题主色 / 辅助色 / 渐变色的三个小圆点。
struct ThemeColorDots: View {
    let palette: ThemePalette
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            dot(palette.primary, label: "主色")
            dot(palette.secondary, label: "辅助色")
            dot(palette.gradientEnd, label: "渐变")
        }
    }

    private func dot(_ color: RGBColor, label: String) -> some View {
        Circle()
            .fill(color.color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
            .accessibilityLabel(label)
    }
}

// MARK: - 主题设置页预览小部件

/// 主题卡片底部的渐变条（主色 → 辅助色 → 渐变结束色）。
struct ThemeGradientStrip: View {
    let theme: AppTheme

    var body: some View {
        LinearGradient(
            colors: [
                theme.light.primary.color,
                theme.light.secondary.color,
                theme.light.gradientEnd.color
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 4)
        .clipShape(Capsule())
    }
}

// MARK: - 实时预览总览卡（本主题）

/// 主题设置页顶部的「实时预览」：大尺寸 App 首页模拟 + 主题名 + 说明。
struct ThemeLivePreviewCard: View {
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            ThemeAppPreview(colors: theme.colors, compact: false)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(colors.hairline, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 18, x: 0, y: 8)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: theme.theme.symbolName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(colors.primary)
                        Text(theme.theme.name)
                            .font(.headline)
                            .foregroundStyle(colors.textPrimary)
                    }
                    Text(theme.theme.subtitle)
                        .font(.caption)
                        .foregroundStyle(colors.textSecondary)
                }
                Spacer()
                Label("已应用", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colors.primary)
                    .accessibilityIdentifier("theme.applied")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(colors.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(colors.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 6)
    }

    private var colors: ThemeColors { theme.colors }
}

#if DEBUG
#Preview("ThemeAppPreview") {
    ThemeAppPreview(colors: AppTheme.purpleDream.resolvedColors)
        .padding()
}
#endif
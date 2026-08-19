import SwiftUI
import UIKit

/// 主题设置页（Apple 设置风格）：
/// - 顶部：实时预览大卡（随选择即时刷新 App 首页模拟图）
/// - 中部：8 套主题卡片（名称 / 迷你首页预览 / 色彩展示 / 选中态）
/// - 底部：外观模式（跟随系统 / 浅色 / 深色）
///
/// 本页颜色全部来自 `@EnvironmentObject ThemeManager`，因此主题或外观
/// 变化时页面本身也会实时刷新；它是一个 sheet，挂在根视图上，
/// 不会被主题切换时的全局重建顶掉，保证「点击立即切换」的完整体验。
struct ThemeSettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ThemeLivePreviewCard()
                    themeSection
                    appearanceSection
                }
                .padding(.horizontal, DSpace.lg)
                .padding(.top, DSpace.sm)
                .padding(.bottom, 36)
            }
            .background(pageBackground)
            .navigationTitle("主题设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.primary)
                }
            }
            .sensoryFeedback(.selection, trigger: theme.themeID)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - 页面背景（品牌光晕 + 基色，柔和有层次）

    private var pageBackground: some View {
        ZStack {
            colors.background
            // 顶部柔和的品牌光晕，营造通透感
            LinearGradient(
                colors: [colors.gradientStart.opacity(0.10), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .frame(height: 260)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
    }

    // MARK: - 主题卡片区

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("主题", symbol: "paintpalette.fill")

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(AppTheme.all) { t in
                    themeCard(t)
                }
            }
        }
    }

    private func themeCard(_ t: AppTheme) -> some View {
        let isSelected = theme.themeID == t.id
        let cardColors = t.resolvedColors

        return Button {
            theme.select(theme: t)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                // 迷你首页预览
                HStack {
                    Spacer()
                    ThemeAppPreview(colors: cardColors, compact: true)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(cardColors.hairline, lineWidth: 0.5)
                        )
                    Spacer()
                }

                // 名称 + 选中状态
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: t.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(cardColors.primary)
                    Text(t.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(isSelected ? colors.primary : colors.textTertiary)
                        .contentTransition(.symbolEffect(.replace))
                }

                Text(t.subtitle)
                    .font(.caption2)
                    .foregroundStyle(colors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                ThemeColorDots(palette: t.light)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? colors.primary.opacity(0.55) : colors.hairline,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .shadow(
                color: .black.opacity(isSelected ? 0.12 : 0.05),
                radius: 10, x: 0, y: 4
            )
        }
        .buttonStyle(DSScaleButtonStyle())
        .animation(AppAnimation.spring, value: isSelected)
        .accessibilityIdentifier("theme.card.\(t.id)")
    }

    // MARK: - 外观模式区

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("外观", symbol: "circle.lefthalf.filled")

            VStack(spacing: 0) {
                ForEach(Array(AppearanceMode.allCases.enumerated()), id: \.element.id) { index, mode in
                    appearanceRow(mode)
                    if index < AppearanceMode.allCases.count - 1 {
                        Rectangle()
                            .fill(colors.hairline)
                            .frame(height: 0.5)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(colors.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(colors.hairline, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }

    private func appearanceRow(_ mode: AppearanceMode) -> some View {
        let isSelected = theme.appearanceMode == mode
        return Button {
            theme.setAppearance(mode)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(colors.iconColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(colors.primary.opacity(0.12)))

                Text(mode.title)
                    .font(.subheadline)
                    .foregroundStyle(colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(colors.primary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .padding(.horizontal, DSpace.lg)
            .padding(.vertical, DSpace.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(AppAnimation.smooth, value: isSelected)
        .accessibilityIdentifier("appearance.\(mode.rawValue)")
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(colors.primary)
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(colors.textSecondary)
        }
        .padding(.leading, 4)
    }

    /// 本页颜色快捷访问：跟随当前主题实时刷新
    private var colors: ThemeColors { theme.colors }
}

#if DEBUG
#Preview("ThemeSettings") {
    ThemeSettingsView()
        .environmentObject(ThemeManager.shared)
}
#endif
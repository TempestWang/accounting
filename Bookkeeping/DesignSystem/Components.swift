import SwiftUI
import UIKit

// MARK: - 统一卡片

/// 高级化卡片容器：连续圆角 + 发丝描边 + 浅投影（Dark Mode 自动弱化投影）。
/// UI优化：参考设计稿调整卡片样式
struct DSCard: ViewModifier {
    var padding: CGFloat = DSpace.lg
    var radius: CGFloat = DRadius.card
    var fill: Color? = nil

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(cardBackground)
    }

    /// 卡片背景：圆角连续填充 + 发丝描边 + 阴影
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(fill ?? DSColor.cardBackground)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(DSColor.hairline, lineWidth: 0.5)
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0 : 0.04),
            radius: 8, x: 0, y: 2
        )
    }
}

extension View {
    /// 标准卡片样式
    func cardStyle() -> some View {
        modifier(DSCard())
    }

    /// 卡片样式（可自定义内边距 / 圆角 / 填充）
    func dsCard(padding: CGFloat = DSpace.lg,
                radius: CGFloat = DRadius.card,
                fill: Color? = nil) -> some View {
        modifier(DSCard(padding: padding, radius: radius, fill: fill))
    }
}

// MARK: - 分类图标（圆角方形，Apple 质感）

/// 分类图标：柔和底色 + 细描边 + 点选放大动画。
/// UI优化：参考设计稿调整图标样式
struct DSCategoryIcon: View {
    let icon: String
    let color: Color
    var size: CGFloat = 44
    var selected: Bool = false

    var body: some View {
        ZStack {
            // UI优化：参考设计稿使用渐变底色
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(selected ? 0.35 : 0.15),
                            color.opacity(selected ? 0.20 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(
                    selected ? color.opacity(0.8) : color.opacity(0.15),
                    lineWidth: selected ? 1.5 : 0.5
                )
            DSCategoryGlyph(icon: icon, color: color, size: size * 0.42)
        }
        .frame(width: size, height: size)
        .scaleEffect(selected ? 1.08 : 1)
        .shadow(color: selected ? color.opacity(0.3) : .clear, radius: 8, y: 3)
        .animation(AppAnimation.spring, value: selected)
    }
}

/// 分类可使用内置 SF Symbol 或用户通过输入法输入的表情。
struct DSCategoryGlyph: View {
    let icon: String
    let color: Color
    let size: CGFloat

    var body: some View {
        if icon.containsEmojiGlyph {
            Text(icon)
                .font(.system(size: size))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        } else {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(color)
        }
    }
}

extension String {
    /// Emoji 可能由多个 Unicode scalar 组成，因此按 scalar 属性判断而非字符串长度。
    var containsEmojiGlyph: Bool {
        unicodeScalars.contains { $0.properties.isEmoji }
    }
}

// MARK: - 金额文本

/// 金额展示：统一 SF Pro Rounded + 语义色 + 数字滚动动画。
/// 文本保持 DateFormatters 输出格式（如 -¥38.00），不改变任何数据格式约定。
struct DSAmountText: View {
    let value: Decimal
    let type: TransactionType
    var font: Font = Typography.moneyBody
    var color: Color? = nil

    var body: some View {
        Text(DateFormatters.signedMoney(value, type: type))
            .font(font)
            .foregroundStyle(color ?? (type == .expense ? DSColor.expense : DSColor.income))
            .contentTransition(.numericText())
            .minimumScaleFactor(0.7)
            .lineLimit(1)
    }
}

// MARK: - 空状态

/// 统一空状态：柔和圆底图标 + 标题 + 说明。
struct DSEmptyView: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(DSColor.secondaryFill).frame(width: 84, height: 84)
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(.primary)
            if let message {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DSpace.xxl)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - 胶囊标签

/// 轻量状态标签：可选「柔底」或「实心」两种形态。
struct DSPill: View {
    let text: String
    var color: Color = DSColor.primary
    var solid: Bool = false

    private var fill: Color { solid ? color : color.opacity(0.13) }
    private var content: Color { solid ? .white : color }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(content)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(fill))
    }
}

// MARK: - 胶囊小按钮

/// 卡片内的轻量操作按钮（管理 / 设置 / 回到本月等）
struct DSPillButton: View {
    let title: String
    var color: Color = DSColor.primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            DSPill(text: title, color: color)
        }
        .buttonStyle(DSPlainButtonStyle())
        .pressFeedback()
    }
}

// MARK: - 主按钮

/// 主操作按钮：全宽、圆角、按压反馈。
/// 未指定 tint 时使用当前主题的按钮样式（实心主色 / 品牌渐变），
/// 并自动使用与填充对比度正确的按钮文字色。
struct DSPrimaryButton: View {
    let title: String
    /// 自定义填充色；为 nil 时走主题按钮样式
    var tint: Color? = nil
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(tint == nil ? DSColor.buttonText : Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(buttonBackground(enabled: enabled))
        }
        .buttonStyle(DSScaleButtonStyle())
        .disabled(!enabled)
        .animation(AppAnimation.smooth, value: enabled)
    }

    @ViewBuilder
    private func buttonBackground(enabled: Bool) -> some View {
        RoundedRectangle(cornerRadius: DRadius.medium + 2, style: .continuous)
            .fill(enabled ? fillGradient : AnyShapeStyle(DSColor.secondaryFill))
    }

    /// 填充：显式 tint 时退化为该色渐变；否则使用当前主题按钮样式的渐变
    private var fillGradient: AnyShapeStyle {
        if let tint {
            return AnyShapeStyle(LinearGradient(
                colors: [tint, tint.opacity(0.85)],
                startPoint: .leading,
                endPoint: .trailing
            ))
        }
        return AnyShapeStyle(LinearGradient(
            colors: ThemeManager.shared.theme.buttonStyle.gradientColors,
            startPoint: .leading,
            endPoint: .trailing
        ))
    }
}

// MARK: - 图标统计列（卡片内迷你统计）

/// 卡片内单列统计：标题 + 数值 + 图标。
struct DSStatColumn: View {
    let title: String
    let value: String
    var color: Color = DSColor.primary
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(color.opacity(0.9))
                }
                Text(title)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(Typography.moneyTitle)
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
    }
}

/// 卡片内垂直分隔线
struct DSColumnDivider: View {
    var body: some View {
        Rectangle()
            .fill(DSColor.hairline)
            .frame(width: 1, height: 32)
            .padding(.horizontal, DSpace.md)
    }
}

// MARK: - 胶囊筛选器

/// 自定义胶囊筛选（替代原生 Segmented 用于页面级筛选）：
/// 柔底容器 + 选中胶囊 + 弹性动画，视觉更轻盈；同时避免与表单内的
/// 原生「支出/收入」分段控件产生无障碍歧义。
struct DSFilterPills<Value: Hashable>: View {
    let options: [(title: String, value: Value)]
    @Binding var selection: Value
    var tint: Color = DSColor.primary

    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.value) { option in
                let isSelected = selection == option.value
                Button {
                    withSmoothAnimation(AppAnimation.spring) {
                        selection = option.value
                    }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? DSColor.buttonText : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(isSelected ? tint : .clear)
                        )
                }
                .buttonStyle(DSPlainButtonStyle())
            }
        }
        .padding(3)
        .background(Capsule().fill(DSColor.secondaryFill))
    }
}

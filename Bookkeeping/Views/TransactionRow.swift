import SwiftUI

/// 明细 / 首页最近流水共用的一行：分类图标 + 名称/时间/备注 + 右侧金额突出。
/// UI优化：根据设计稿调整图标和布局样式
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            // UI优化：参考设计稿使用圆角方形图标背景
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(categoryColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                DSCategoryGlyph(icon: categoryIcon, color: categoryColor, size: 19)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(categoryName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if isAutoRecorded {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundStyle(DSColor.warning)
                    }
                }
                HStack(spacing: 4) {
                    Text(DateFormatters.shortTime(transaction.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !transaction.note.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 8)

            Text(DateFormatters.signedMoney(transaction.amount, type: transaction.type))
                .font(Typography.moneyBody)
                .foregroundStyle(transaction.type == .expense ? DSColor.expense : DSColor.income)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: 派生数据

    private var categoryName: String {
        transaction.category?.name ?? "未分类"
    }

    private var categoryIcon: String {
        transaction.category?.icon ?? "questionmark"
    }

    private var categoryColor: Color {
        ColorPalette.color(for: categoryName)
    }

    private var isAutoRecorded: Bool {
        transaction.source != "手动"
    }
}

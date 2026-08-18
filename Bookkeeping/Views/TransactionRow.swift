import SwiftUI

/// 明细列表的一行
struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 12) {
            categoryBadge
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(transaction.category?.name ?? "未分类")
                        .font(.body)
                    if isAutoRecorded {
                        Image(systemName: "camera.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                if !transaction.note.isEmpty {
                    Text(transaction.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(DateFormatters.signedMoney(transaction.amount, type: transaction.type))
                .font(.body.weight(.semibold))
                .foregroundStyle(transaction.type == .expense ? .red : .green)
        }
        .padding(.vertical, 2)
    }

    /// 快捷指令 / 分享自动记账的条目
    private var isAutoRecorded: Bool {
        transaction.source != "手动"
    }

    private var categoryBadge: some View {
        let name = transaction.category?.name ?? "未分类"
        let icon = transaction.category?.icon ?? "questionmark"
        let color = ColorPalette.color(for: name)
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
        }
    }
}

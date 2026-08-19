import SwiftUI
import SwiftData

/// 待确认账单列表（多笔场景）：点击进入确认页逐笔处理。
/// 单笔场景由 ContentView 直接弹出确认页，不经过本列表。
/// UI优化：根据设计稿调整列表样式
struct PendingTransactionListView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PendingTransaction.createdAt, order: .reverse)
    private var pendings: [PendingTransaction]

    var body: some View {
        List {
            Section {
                ForEach(pendings) { pending in
                    NavigationLink {
                        ConfirmTransactionView(pending: pending)
                    } label: {
                        row(pending)
                    }
                }
            } header: {
                Text("识别结果仅作为草稿，确认保存后才会记账")
                    .textCase(nil)
            }
        }
        .background(DSColor.background)
        .navigationTitle("待确认账单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
                    .foregroundStyle(DSColor.primary)
            }
        }
        .overlay {
            if pendings.isEmpty {
                DSEmptyView(
                    icon: "checkmark.circle",
                    title: "没有待确认的账单",
                    message: "快捷指令识别后的账单会出现在这里。"
                )
            }
        }
    }

    private func row(_ pending: PendingTransaction) -> some View {
        HStack(spacing: AppSpacing.m) {
            // UI优化：参考设计稿使用圆角方形图标
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DSColor.healthy.opacity(0.15))
                    .frame(width: 40, height: 40)
                Text(String(pending.merchant.prefix(1)).isEmpty ? "账" : String(pending.merchant.prefix(1)))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DSColor.healthy)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(pending.merchant.isEmpty ? "未识别商户" : pending.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text([pending.categoryName.isEmpty ? "分类待选择" : pending.categoryName,
                      DateFormatters.dayHeader(pending.date)]
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text("¥\(DateFormatters.money(pending.amount))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(pending.type == .expense ? DSColor.expense : DSColor.income)
                if pending.needsReview || pending.amount <= 0 {
                    Text("待核对")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DSColor.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(DSColor.warning.opacity(0.15)))
                }
            }
        }
        .padding(.vertical, 2)
    }
}

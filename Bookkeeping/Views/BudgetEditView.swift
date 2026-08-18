import SwiftUI
import SwiftData

/// 预算设置页：大数字输入 + 快捷金额胶囊 + 突出保存按钮，一步完成设置。
struct BudgetEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// 目标月份键（形如 "2026-08"），默认当前月份
    var month: String = DateFormatters.monthKey()

    @Query private var budgets: [Budget]
    @State private var amountText: String = ""
    @State private var showError = false
    @State private var errorText = ""
    @FocusState private var amountFocused: Bool

    /// 快捷预设金额（整百元档位）
    private static let presets: [Int] = [3000, 5000, 8000, 10000]

    private var current: Budget? {
        budgets.first { $0.month == month }
    }

    private var isCurrentMonth: Bool {
        month == DateFormatters.monthKey()
    }

    /// 当前输入解析出的合法金额（nil 表示未输入或非法）
    private var parsedAmount: Decimal? {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")), amount > 0 else { return nil }
        return amount
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xxl) {
                    VStack(spacing: AppSpacing.xs) {
                        Text("设置预算 · \(BudgetService.monthTitle(month))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("这个月最多花多少？")
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, AppSpacing.xl)

                    amountInput

                    presetChips

                    saveButton

                    if current != nil {
                        deleteButton
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.bottom, AppSpacing.xxxl)
            }
            .background(AppTheme.budgetBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { amountFocused = false }
                }
            }
            .onAppear {
                if let current {
                    amountText = "\(current.amount)"
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorText)
            }
        }
    }

    // MARK: - 输入区

    private var amountInput: some View {
        VStack(spacing: AppSpacing.xs) {
            Capsule()
                .fill(AppTheme.budgetGradient)
                .frame(width: 44, height: 5)
                .padding(.bottom, AppSpacing.s)
            Text("¥")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("0.00", text: $amountText)
                .focused($amountFocused)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .tint(AppTheme.budgetHealthy)
        }
        .padding(.vertical, AppSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppTheme.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }

    // MARK: - 快捷金额

    private var presetChips: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            Text("快速设置")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: AppSpacing.s) {
                ForEach(Self.presets, id: \.self) { value in
                    presetChip(value)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func presetChip(_ value: Int) -> some View {
        let selected = isPresetSelected(value)
        return Button {
            amountText = "\(value)"
            amountFocused = false
        } label: {
            Text("¥\(value)")
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(
                    Capsule().fill(selected ? AppTheme.budgetHealthy : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: selected)
    }

    private func isPresetSelected(_ value: Int) -> Bool {
        guard let parsed = parsedAmount else { return false }
        return parsed == Decimal(value)
    }

    // MARK: - 操作

    private var saveButton: some View {
        let canSave = parsedAmount != nil
        return Button {
            save()
        } label: {
            Text("保存预算")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.input + 4)
                        .fill(canSave ? AppTheme.budgetHealthy : Color(.systemGray4))
                        .shadow(color: canSave ? AppTheme.budgetHealthy.opacity(0.3) : .clear, radius: 8, y: 4)
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .animation(.easeOut(duration: 0.2), value: canSave)
    }

    private var deleteButton: some View {
        Button("删除该月预算", role: .destructive) {
            deleteBudget()
        }
        .font(.subheadline)
        .padding(.top, AppSpacing.s)
    }

    private func save() {
        guard let amount = parsedAmount else {
            errorText = "请输入大于 0 的合法金额（最多 9 位整数和 2 位小数）。"
            showError = true
            return
        }
        do {
            // 先查后插：同一月份仅保留一条预算记录
            if let current {
                current.amount = amount
            } else {
                context.insert(Budget(month: month, amount: amount))
            }
            try context.save()
            dismiss()
        } catch {
            errorText = "保存失败，请重试。"
            showError = true
        }
    }

    private func deleteBudget() {
        guard let current else { return }
        context.delete(current)
        do {
            try context.save()
            dismiss()
        } catch {
            errorText = "删除失败，请重试。"
            showError = true
        }
    }
}
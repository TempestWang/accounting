import SwiftUI
import SwiftData

/// 预算设置页：大数字输入 + 快捷金额胶囊 + 突出保存按钮，一步完成设置。
/// UI优化：参考设计稿调整按钮样式
struct BudgetEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Query private var budgets: [Budget]
    @State private var amountText: String = ""
    @State private var showError = false
    @State private var errorText = ""
    @FocusState private var amountFocused: Bool

    /// 快捷预设金额（整百元档位）
    private static let presets: [Int] = [3000, 5000, 8000, 10000]

    private var current: Budget? {
        BudgetService.permanentBudget(from: budgets)
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
                        Text("设置每月预算")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("每个月最多花多少？")
                            .font(.system(size: 26, weight: .bold))
                            .multilineTextAlignment(.center)
                        Text("保存后会持续应用于每个月")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            // UI优化：根据设计稿调整背景色
            .background(DSColor.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.secondary)
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
            // UI优化：参考设计稿使用紫色指示条
            Capsule()
                .fill(DSColor.primary)
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
                .tint(DSColor.primary)
        }
        .padding(.vertical, AppSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(DSColor.cardBackground)
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
                .foregroundStyle(selected ? DSColor.buttonText : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.m)
                .background(
                    Capsule().fill(selected ? DSColor.primary : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(DSPlainButtonStyle())
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
                .foregroundStyle(DSColor.buttonText)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    canSave
                        ? AnyView(
                            RoundedRectangle(cornerRadius: AppRadius.input + 4)
                                .fill(
                                    LinearGradient(
                                        colors: [DSColor.primary, DSColor.purpleGradientEnd],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: DSColor.primary.opacity(0.3), radius: 8, y: 4)
                          )
                        : AnyView(
                            RoundedRectangle(cornerRadius: AppRadius.input + 4)
                                .fill(Color(.systemGray4))
                          )
                )
        }
        .buttonStyle(DSPlainButtonStyle())
        .disabled(!canSave)
        .animation(.easeOut(duration: 0.2), value: canSave)
    }

    private var deleteButton: some View {
        Button("删除每月预算", role: .destructive) {
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
            // 首次保存时把旧版按月预算转换为永久预算，并合并其余旧记录。
            let permanent: Budget
            if let current {
                current.amount = amount
                current.month = "permanent"
                current.isPermanent = true
                permanent = current
            } else {
                permanent = Budget(amount: amount)
                context.insert(permanent)
            }
            for budget in budgets where budget !== permanent {
                context.delete(budget)
            }
            try context.save()
            dismiss()
        } catch {
            errorText = "保存失败，请重试。"
            showError = true
        }
    }

    private func deleteBudget() {
        for budget in budgets {
            context.delete(budget)
        }
        do {
            try context.save()
            dismiss()
        } catch {
            errorText = "删除失败，请重试。"
            showError = true
        }
    }
}

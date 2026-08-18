import SwiftUI
import SwiftData

/// 待确认账单的确认 / 编辑页：
/// - 顶部渐变卡展示「已识别一笔账单」汇总，提供明确的确认感；
/// - 金额大输入 + 收支切换；
/// - 商户 / 分类 / 日期 / 备注全部可修改；
/// - 底部固定「放弃 / 保存」；金额非法时保存不可用；
/// - 保存后才写入正式 Transaction 并删除草稿；放弃则不产生任何账单。
struct ConfirmTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let pending: PendingTransaction

    @State private var amountText: String = ""
    @State private var type: TransactionType = .expense
    @State private var merchant: String = ""
    @State private var categoryName: String = ""
    @State private var date: Date = Date()
    @State private var note: String = ""

    @State private var showCategoryPicker = false
    @State private var showDiscardConfirm = false
    @State private var showScreenshot = false
    @State private var showError = false
    @State private var errorText = ""

    @FocusState private var amountFocused: Bool

    /// 日期快捷方式
    private enum DateMode: String, CaseIterable, Identifiable {
        case today = "今天"
        case yesterday = "昨天"
        case custom = "自定义"
        var id: String { rawValue }
    }

    @State private var dateMode: DateMode = .custom

    /// 当前输入金额是否合法（决定保存按钮可用性）
    private var validAmount: Decimal? {
        TransactionImportService.parseAmount(amountText)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.l) {
                headerCard
                if pending.screenshotData != nil {
                    screenshotCard
                }
                amountCard
                fieldsCard
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.top, AppSpacing.s)
            .padding(.bottom, AppSpacing.l)
        }
        .background(AppTheme.background)
        .navigationTitle("确认账单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { showDiscardConfirm = true }
            }
        }
        .safeAreaInset(edge: .bottom) { saveBar }
        .sheet(isPresented: $showCategoryPicker) {
            NavigationStack {
                CategoryPickerSheet(type: type, selectedName: $categoryName)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showScreenshot) {
            if let data = pending.screenshotData, let uiImage = UIImage(data: data) {
                ZoomableImageSheet(image: uiImage)
            }
        }
        .alert("提示", isPresented: $showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorText)
        }
        .alert("放弃这笔账单？", isPresented: $showDiscardConfirm) {
            Button("放弃", role: .destructive) { discard() }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("放弃后不会创建任何账单记录。")
        }
        .onAppear(perform: loadFromPending)
    }

    // MARK: - 初始化

    private func loadFromPending() {
        if pending.amount > 0 {
            amountText = "\(pending.amount)"
        }
        type = pending.type
        merchant = pending.merchant
        categoryName = pending.categoryName
        date = pending.date
        note = pending.note

        // 根据日期推断快捷模式
        let cal = Calendar.current
        if cal.isDateInToday(pending.date) {
            dateMode = .today
        } else if cal.isDateInYesterday(pending.date) {
            dateMode = .yesterday
        } else {
            dateMode = .custom
        }
    }

    // MARK: - 区块

    /// 顶部确认感卡片
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            HStack {
                Text("已识别一笔账单")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                if pending.needsReview {
                    Text("⚠️ 请核对")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.m)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.25)))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("¥")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                Text(validAmount.map(DateFormatters.money) ?? "0.00")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(merchant.isEmpty ? "商户未识别" : merchant)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
                Text([categoryName.isEmpty ? "分类待选择" : categoryName,
                      DateFormatters.dayHeader(date)]
                    .joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Text("识别结果仅供参考，请核对后保存")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(AppTheme.budgetGradient)
                .shadow(color: AppTheme.budgetHealthy.opacity(0.25), radius: 14, y: 6)
        )
    }

    /// 原始截图（可点击查看原图）
    private var screenshotCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Label("原始截图", systemImage: "photo")
                .font(.subheadline.weight(.semibold))
            Button {
                showScreenshot = true
            } label: {
                if let data = pending.screenshotData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                }
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppTheme.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }

    /// 金额编辑卡
    private var amountCard: some View {
        VStack(spacing: AppSpacing.m) {
            Picker("类型", selection: $type) {
                Text("支出").tag(TransactionType.expense)
                Text("收入").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            TextField("0.00", text: $amountText)
                .focused($amountFocused)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .tint(AppTheme.budgetHealthy)
                .overlay(alignment: .leading) {
                    Text("¥")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .offset(x: -40)
                }

            Text(validAmount == nil ? "请输入大于 0 的金额" : "金额将计入本月\(type == .expense ? "支出" : "收入")")
                .font(.caption)
                .foregroundStyle(validAmount == nil ? AppTheme.expense : .secondary)
        }
        .padding(AppSpacing.xl)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppTheme.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }

    /// 字段编辑卡
    private var fieldsCard: some View {
        VStack(spacing: 0) {
            fieldRow(label: "商户", icon: "storefront") {
                TextField("商户（如：星巴克）", text: $merchant)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
            }
            fieldDivider
            fieldRow(label: "分类", icon: "square.grid.2x2") {
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(categoryName.isEmpty ? "请选择" : categoryName)
                            .foregroundStyle(categoryName.isEmpty ? Color.secondary : Color.primary)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            fieldDivider
            dateSection
            fieldDivider
            fieldRow(label: "备注", icon: "text.alignleft") {
                TextField("备注（选填）", text: $note)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(AppTheme.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }

    private func fieldRow<Content: View>(label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: AppSpacing.m) {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            content()
        }
        .padding(.vertical, AppSpacing.m)
    }

    private var fieldDivider: some View {
        Divider()
    }

    private var dateSection: some View {
        VStack(spacing: AppSpacing.m) {
            HStack(spacing: AppSpacing.m) {
                Label("日期", systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $dateMode) {
                    ForEach(DateMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            .padding(.vertical, AppSpacing.m)

            if dateMode == .custom {
                DatePicker("选择日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    // 强制中文环境：日期选择器内部（月份、星期、按钮）不随系统语言显示英文
                    .environment(\.locale, Locale(identifier: "zh_CN"))
            }
        }
        .onChange(of: dateMode) { _, mode in
            let cal = Calendar.current
            switch mode {
            case .today:
                date = Date()
            case .yesterday:
                date = cal.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            case .custom:
                break
            }
        }
    }

    // MARK: - 底部操作

    private var saveBar: some View {
        HStack(spacing: AppSpacing.m) {
            Button {
                showDiscardConfirm = true
            } label: {
                Text("放弃")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 84, height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.input + 4)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)

            Button {
                save()
            } label: {
                Text("保存账单")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.input + 4)
                            .fill(validAmount == nil ? Color(.systemGray4) : AppTheme.budgetHealthy)
                            .shadow(color: validAmount == nil ? .clear : AppTheme.budgetHealthy.opacity(0.3), radius: 8, y: 4)
                    )
            }
            .buttonStyle(.plain)
            .disabled(validAmount == nil)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.s)
        .background(.ultraThinMaterial)
    }

    // MARK: - 动作

    private func save() {
        guard let amount = validAmount else {
            errorText = "请输入大于 0 的合法金额（最多 9 位整数和 2 位小数）。"
            showError = true
            return
        }
        do {
            _ = try TransactionImportService.confirmAndSave(
                pending,
                amount: amount,
                type: type,
                merchant: merchant,
                categoryName: categoryName,
                date: date,
                note: note,
                in: context
            )
            dismiss()
        } catch {
            // 不直接透出系统错误原文（可能为英文），统一中文提示
            errorText = "保存失败，请重试。"
            showError = true
        }
    }

    private func discard() {
        TransactionImportService.discard(pending, in: context)
        dismiss()
    }
}

// MARK: - 分类选择

/// 复用当前 App 的 Category 数据（按收支类型过滤），选择后回填名称。
private struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let type: TransactionType
    @Binding var selectedName: String

    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    private var items: [Category] {
        categories.filter { $0.type == type }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: AppSpacing.l) {
                ForEach(items) { cat in
                    Button {
                        selectedName = cat.name
                        dismiss()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 20))
                                .frame(width: 48, height: 48)
                                .background(
                                    Circle().fill(
                                        ColorPalette.color(for: cat.name)
                                            .opacity(selectedName == cat.name ? 0.35 : 0.12)
                                    )
                                )
                                .foregroundStyle(ColorPalette.color(for: cat.name))
                            Text(cat.name)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.l)
        }
        .background(AppTheme.background)
        .navigationTitle("选择分类")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
    }
}

// MARK: - 截图查看

/// 全屏查看原始截图
private struct ZoomableImageSheet: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        NavigationStack {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            .background(Color.black)
            .navigationTitle("原始截图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
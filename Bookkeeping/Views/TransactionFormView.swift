import SwiftUI
import SwiftData

/// 记一笔 / 编辑 / 预填确认 的通用表单
///
/// 设计重点：金额为页面视觉中心（大号 Rounded 数字），
/// 收支切换使用原生分段控件（自带平滑滑动动画），
/// 分类以圆角方形图标网格展示，选中带放大 + 描边动画。
struct TransactionFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let editing: Transaction?
    let prefill: PrefillData?
    /// 首页快捷记账时预选分类
    let preselectCategory: Category?

    @State private var type: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var selectedCategory: Category?
    @State private var date: Date = Date()
    @State private var note: String = ""
    @State private var showError = false
    @State private var errorText = ""

    @ScaledMetric(relativeTo: .body) private var categoryIconSize: CGFloat = 56

    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    init(editing: Transaction? = nil, prefill: PrefillData? = nil, preselectCategory: Category? = nil) {
        self.editing = editing
        self.prefill = prefill
        self.preselectCategory = preselectCategory
        _type = State(initialValue: preselectCategory?.type ?? editing?.type ?? prefill?.type ?? .expense)
        _amountText = State(initialValue: prefill?.amountText ?? (editing.map { "\($0.amount)" } ?? ""))
        _date = State(initialValue: prefill?.date ?? editing?.date ?? Date())
        _note = State(initialValue: prefill?.note ?? editing?.note ?? "")
        _selectedCategory = State(initialValue: nil)
    }

    /// 当前收支的语义色（金额 / 分段控件 / 说明文字）
    private var accentColor: Color {
        type == .expense ? DSColor.expense : DSColor.income
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    amountCard
                    categoryCard
                    dateNoteCard
                    typeCard
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.s)
                .padding(.bottom, AppSpacing.xxl)
            }
            // UI优化：根据设计稿调整背景色
            .background(DSColor.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(editing == nil ? "记一笔" : "编辑账目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(DSColor.primary)
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorText)
            }
            .onAppear {
                resolveInitialCategory()
            }
            .onChange(of: type) { _, newType in
                // 切换收支时自动选中新类型下的第一个分类（带动画）
                withSmoothAnimation(AppAnimation.spring) {
                    selectedCategory = categoriesFor(newType).first
                }
            }
        }
    }

    // MARK: - 区块：收支切换（UI优化：调整为轻量样式）

    private var typeCard: some View {
        VStack(spacing: 10) {
            // UI优化：参考设计稿使用自定义分段控件样式
            HStack(spacing: 0) {
                ForEach([TransactionType.expense, TransactionType.income], id: \.self) { t in
                    Button {
                        withSmoothAnimation(AppAnimation.spring) {
                            type = t
                        }
                    } label: {
                        Text(t == .expense ? "支出" : "收入")
                            .font(.subheadline.weight(type == t ? .semibold : .regular))
                            .foregroundStyle(type == t ? DSColor.buttonText : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(type == t ? DSColor.primary : .clear)
                            )
                    }
                    .buttonStyle(DSPlainButtonStyle())
                }
            }
            .padding(3)
            .background(Capsule().fill(DSColor.secondaryFill))

            Text("金额将计入本月\(type == .expense ? "支出" : "收入")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .contentTransition(.opacity)
                .animation(AppAnimation.content, value: type)
        }
        .dsCard(padding: AppSpacing.m + 2)
    }

    // MARK: - 区块：金额（视觉中心）

    private var amountCard: some View {
        VStack(spacing: 8) {
            // UI优化：金额区域更突出
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("¥")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(accentColor)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .tint(accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)

            // UI优化：参考设计稿添加提示文字
            Text("点击输入金额")
                .font(.caption)
                .foregroundStyle(amountText.isEmpty ? Color(.tertiaryLabel) : Color.clear)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .dsCard(padding: DSpace.xl)
        .animation(AppAnimation.content, value: type)
    }

    // MARK: - 区块：分类图标网格

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("选择分类")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            let items = categoriesFor(type)
            // iPad 等宽屏下增加列数，避免网格过宽
            let columns = Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 8 : 4)
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(items) { cat in
                    let isSelected = selectedCategory?.id == cat.id
                    Button {
                        withSmoothAnimation(AppAnimation.spring) {
                            selectedCategory = cat
                        }
                    } label: {
                        VStack(spacing: 6) {
                            DSCategoryIcon(
                                icon: cat.icon,
                                color: ColorPalette.color(for: cat.name),
                                size: categoryIconSize,
                                selected: isSelected
                            )
                            Text(cat.name)
                                .font(.caption)
                                .foregroundStyle(isSelected ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .buttonStyle(DSScaleButtonStyle())
                }
            }
        }
        .dsCard(padding: AppSpacing.l)
    }

    // MARK: - 区块：日期与备注

    private var dateNoteCard: some View {
        VStack(spacing: 0) {
            HStack {
                Label("日期", systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    // 强制中文环境：日期选择器内部（月份、星期、按钮）不随系统语言显示英文
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    .tint(accentColor)
            }
            .padding(.vertical, AppSpacing.m)

            Rectangle()
                .fill(DSColor.hairline)
                .frame(height: 1)

            HStack {
                Label("备注", systemImage: "text.alignleft")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("备注（如商户名）", text: $note)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, AppSpacing.m)
        }
        .dsCard(padding: AppSpacing.l)
    }

    // MARK: - 逻辑

    private func categoriesFor(_ type: TransactionType) -> [Category] {
        categories.filter { $0.type == type }
    }

    private func resolveInitialCategory() {
        guard selectedCategory == nil else { return }
        let items = categoriesFor(type)
        if let preselectCategory, preselectCategory.type == type {
            selectedCategory = preselectCategory
        } else if let editing, let cat = editing.category, cat.type == type {
            selectedCategory = cat
        } else if let name = prefill?.categoryName,
                  let match = items.first(where: { $0.name == name }) {
            selectedCategory = match
        } else if editing == nil {
            selectedCategory = items.first
        }
        // 编辑已有流水但原分类已被删除时：保持未选中，让用户明确重新选择，避免静默改分类
    }

    private func save() {
        let cleaned = amountText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let intPart = cleaned.split(separator: ".", omittingEmptySubsequences: false).first ?? ""
        let fracPart = cleaned.contains(".") ? String(cleaned.split(separator: ".", omittingEmptySubsequences: false)[1]) : ""
        // 显式指定 POSIX locale，避免区域设置导致金额解析错误；限制 9 位整数 + 2 位小数
        guard let amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
              amount > 0,
              intPart.count <= 9,
              fracPart.count <= 2 else {
            errorText = "请输入大于 0 的金额，最多 9 位整数和 2 位小数。"
            showError = true
            return
        }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            if let editing {
                editing.amount = amount
                editing.date = date
                editing.note = trimmedNote
                editing.type = type
                editing.category = selectedCategory
            } else {
                let tx = Transaction(
                    amount: amount,
                    date: date,
                    note: trimmedNote,
                    type: type,
                    category: selectedCategory,
                    source: prefill?.source ?? "手动"
                )
                context.insert(tx)
            }
            try context.save()
            dismiss()
        } catch {
            errorText = "保存失败，请重试。"
            showError = true
        }
    }
}

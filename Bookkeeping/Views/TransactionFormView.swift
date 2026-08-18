import SwiftUI
import SwiftData

/// 记一笔 / 编辑 / 预填确认 的通用表单
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

    @ScaledMetric(relativeTo: .body) private var categoryIconSize: CGFloat = 52

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    typePicker
                    amountField
                    datePicker
                    noteField
                }

                Section("分类") {
                    categoryGrid
                }
            }
            .navigationTitle(editing == nil ? "记一笔" : "编辑账目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
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
                // 切换收支时自动选中新类型下的第一个分类
                selectedCategory = categoriesFor(newType).first
            }
        }
    }

    // MARK: - 区块

    private var typePicker: some View {
        Picker("类型", selection: $type) {
            Text("支出").tag(TransactionType.expense)
            Text("收入").tag(TransactionType.income)
        }
        .pickerStyle(.segmented)
    }

    private var amountField: some View {
        HStack {
            Text("¥")
                .font(.title2)
                .foregroundStyle(.secondary)
            TextField("0.00", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.system(size: 34, weight: .semibold))
                .multilineTextAlignment(.leading)
        }
    }

    private var datePicker: some View {
        DatePicker("日期", selection: $date, displayedComponents: [.date, .hourAndMinute])
            // 强制中文环境：日期选择器内部（月份、星期、按钮）不随系统语言显示英文
            .environment(\.locale, Locale(identifier: "zh_CN"))
    }

    private var noteField: some View {
        TextField("备注（如商户名）", text: $note)
    }

    private var categoryGrid: some View {
        let items = categoriesFor(type)
        // iPad 等宽屏下增加列数，避免网格过宽
        let columns = Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 8 : 4)
        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items) { cat in
                Button {
                    selectedCategory = cat
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: cat.icon)
                            .font(.system(size: 22))
                            .frame(width: categoryIconSize, height: categoryIconSize)
                            .background(
                                Circle().fill(
                                    ColorPalette.color(for: cat.name)
                                        .opacity(selectedCategory?.id == cat.id ? 0.35 : 0.12)
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
        .padding(.vertical, 4)
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

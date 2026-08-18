import SwiftUI
import SwiftData

/// 首页（仿鲨鱼记账）：本月收支总览卡 + 快捷记账分类 + 最近流水 + 悬浮「记一笔」
///
/// 数据源：全部为 @Query 响应式数据，新增 / 编辑 / 删除交易后
/// 首页自动刷新，不依赖手动刷新、onAppear 或 dismiss 时序。
struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase

    /// 全部流水（@Query 随数据变化自动更新；仅取最近 8 笔展示）
    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    /// 月份滚动标识：跨月后重建月份总览卡（@Query 谓词随月份变化）
    @State private var monthToken = DateFormatters.monthKey()

    @State private var showForm = false
    @State private var preselectCategory: Category?
    @State private var showRecognition = false
    @State private var editingTransaction: Transaction?
    @State private var showBudgetEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HomeMonthCard(monthKey: monthToken) {
                    showBudgetEdit = true
                }
                .id(monthToken)

                quickRecordSection
                recentSection
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("账本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRecognition = true
                } label: {
                    Image(systemName: "text.viewfinder")
                }
                .accessibilityLabel("从截图识别记账")
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                preselectCategory = nil
                showForm = true
            } label: {
                Label("记一笔", systemImage: "plus")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(AppTheme.gradient))
                    .shadow(color: AppTheme.primary.opacity(0.4), radius: 8, y: 3)
            }
            .padding(.bottom, 6)
        }
        .onChange(of: scenePhase) { _, phase in
            // App 在后台跨月后回到前台：更新月份标识，重建月份卡片
            if phase == .active {
                let key = DateFormatters.monthKey()
                if key != monthToken { monthToken = key }
            }
        }
        .sheet(isPresented: $showForm) {
            TransactionFormView(preselectCategory: preselectCategory)
        }
        .sheet(isPresented: $showRecognition) {
            ImageRecognitionView()
        }
        .sheet(item: $editingTransaction) { tx in
            TransactionFormView(editing: tx)
        }
        .sheet(isPresented: $showBudgetEdit) {
            BudgetEditView()
        }
    }

    // MARK: - 最近流水（全量 @Query 中取最近 8 笔）

    private var recentTransactions: [Transaction] {
        Array(allTransactions.prefix(8))
    }

    // MARK: - 快捷记账

    private var quickRecordSection: some View {
        let expenseCategories = categories.filter { $0.type == .expense }
        return VStack(alignment: .leading, spacing: 12) {
            Text("记一笔")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(expenseCategories) { cat in
                        Button {
                            preselectCategory = cat
                            showForm = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: cat.icon)
                                    .font(.system(size: 22))
                                    .frame(width: 56, height: 56)
                                    .background(Circle().fill(ColorPalette.color(for: cat.name).opacity(0.15)))
                                    .foregroundStyle(ColorPalette.color(for: cat.name))
                                Text(cat.name)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 最近流水

    private var recentSection: some View {
        let recent = recentTransactions
        return VStack(alignment: .leading, spacing: 6) {
            Text("最近流水")
                .font(.headline)

            if recent.isEmpty {
                Text("还没有账目，点下方「记一笔」开始")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, tx in
                    TransactionRow(transaction: tx)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = tx }
                    if index < recent.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - 本月总览卡

/// 本月收支总览卡。月份由 monthKey 决定，@Query 谓词在 init 中构建；
/// 由父视图通过 .id(monthKey) 在跨月时重建。
private struct HomeMonthCard: View {
    let monthKey: String
    var onEditBudget: () -> Void

    @Query private var budgets: [Budget]

    /// 本月流水（谓词限定，避免全量加载；@Query 随数据变化自动更新）
    @Query private var monthTransactions: [Transaction]

    init(monthKey: String, onEditBudget: @escaping () -> Void) {
        self.monthKey = monthKey
        self.onEditBudget = onEditBudget
        let range = BudgetService.monthRange(monthKey)
        let start = range?.start ?? Date()
        let end = range?.end ?? Date()
        _monthTransactions = Query(
            filter: #Predicate<Transaction> { $0.date >= start && $0.date < end },
            sort: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
    }

    private var monthExpense: Decimal {
        monthTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var monthIncome: Decimal {
        monthTransactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var currentBudget: Budget? {
        budgets.first { $0.month == monthKey }
    }

    var body: some View {
        let balance = monthIncome - monthExpense
        return VStack(alignment: .leading, spacing: 14) {
            Text(DateFormatters.monthTitle(Date()))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))

            Text("本月支出")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Text("¥\(DateFormatters.money(monthExpense))")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)

            HStack {
                summaryItem("本月收入", value: monthIncome)
                Spacer()
                summaryItem("结余", value: balance)
            }

            if let budget = currentBudget {
                budgetSection(budget: budget)
            } else {
                noBudgetSection
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.gradient)
        )
    }

    private func summaryItem(_ title: String, value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Text("¥\(DateFormatters.money(value))")
                .font(.headline)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func budgetSection(budget: Budget) -> some View {
        let spent = monthExpense
        let ratio = budget.amount > 0 ? BudgetService.double(spent / budget.amount) : 0
        let remaining = budget.amount - spent
        let over = remaining < 0
        let days = BudgetService.remainingDays(in: monthKey)
        let daily: Decimal? = (remaining > 0 && days > 0) ? remaining / Decimal(days) : nil

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本月预算")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(BudgetService.percentText(ratio))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }

            HStack(alignment: .firstTextBaseline) {
                Text("¥\(DateFormatters.money(budget.amount))")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    onEditBudget()
                } label: {
                    Text("管理")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.25)))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.3))
                    Capsule()
                        .fill(over ? AppTheme.expense : Color.white)
                        .frame(width: geo.size.width * CGFloat(min(ratio, 1)))
                }
            }
            .frame(height: 8)

            HStack {
                Text(over
                     ? "已超支 ¥\(DateFormatters.money(-remaining))"
                     : "剩余 ¥\(DateFormatters.money(remaining))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                if let daily {
                    Text("今日建议 ≤ ¥\(DateFormatters.money(daily))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }

    /// 未设置预算时的提示与入口
    private var noBudgetSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("本月预算")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text("暂未设置预算")
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            Spacer()
            Button {
                onEditBudget()
            } label: {
                Text("设置")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.25)))
            }
        }
    }
}
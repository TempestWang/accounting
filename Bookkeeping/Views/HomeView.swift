import SwiftUI
import SwiftData

/// 首页：本月结余总览卡 + 快捷记账分类 + 最近流水 + 悬浮「记一笔」
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
            VStack(spacing: DSpace.lg) {
                HomeMonthCard(monthKey: monthToken) {
                    showBudgetEdit = true
                }
                .id(monthToken)

                quickRecordSection
                recentSection
            }
            .padding(.horizontal, DSpace.lg)
            .padding(.top, DSpace.sm)
            .padding(.bottom, DSpace.xl)
        }
        // UI优化：根据设计稿调整背景色
        .background(DSColor.background)
        .navigationTitle("账本")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showRecognition = true
                } label: {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 18))
                }
                .accessibilityLabel("从截图识别记账")
            }
        }
        // UI优化：根据设计稿调整悬浮按钮样式
        .safeAreaInset(edge: .bottom) {
            Button {
                preselectCategory = nil
                showForm = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                    Text("记一笔")
                        .font(Typography.headline)
                }
                .foregroundStyle(DSColor.buttonText)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: ThemeManager.shared.theme.buttonStyle.gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: DSColor.primary.opacity(0.4), radius: 12, y: 6)
            }
            .buttonStyle(DSScaleButtonStyle())
            .padding(.bottom, 8)
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
        return VStack(alignment: .leading, spacing: DSpace.md) {
            Text("记一笔")
                .font(Typography.headline)
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSpace.xl) {
                    ForEach(expenseCategories) { cat in
                        Button {
                            withSmoothAnimation(AppAnimation.spring) {
                                preselectCategory = cat
                            }
                            showForm = true
                        } label: {
                            VStack(spacing: 8) {
                                // UI优化：根据设计稿调整分类图标为圆角方形
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    ColorPalette.color(for: cat.name).opacity(0.15),
                                                    ColorPalette.color(for: cat.name).opacity(0.08)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 22, weight: .medium))
                                        .foregroundStyle(ColorPalette.color(for: cat.name))
                                }
                                Text(cat.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(DSScaleButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .cardStyle()
    }

    // MARK: - 最近流水

    private var recentSection: some View {
        let recent = recentTransactions
        return VStack(alignment: .leading, spacing: 4) {
            Text("最近流水")
                .font(Typography.headline)
                .foregroundStyle(.primary)

            if recent.isEmpty {
                DSEmptyView(
                    icon: "tray",
                    title: "还没有账目",
                    message: "点下方「记一笔」开始记录你的第一笔收支。"
                )
                .padding(.vertical, DSpace.xs)
            } else {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, tx in
                    TransactionRow(transaction: tx)
                        .contentShape(Rectangle())
                        .onTapGesture { editingTransaction = tx }
                    if index < recent.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - 本月总览卡

/// 本月结余总览卡：结余大数字 + 收入/支出 + 环比变化 + 预算进度。
/// 月份由 monthKey 决定，@Query 谓词在 init 中构建；
/// 由父视图通过 .id(monthKey) 在跨月时重建。
private struct HomeMonthCard: View {
    let monthKey: String
    var onEditBudget: () -> Void

    @Query private var budgets: [Budget]

    /// 本月流水（谓词限定，避免全量加载；@Query 随数据变化自动更新）
    @Query private var monthTransactions: [Transaction]

    /// 上月流水（用于环比计算）
    @Query private var prevMonthTransactions: [Transaction]

    /// 入场动画标记
    @State private var appeared = false

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
        // 上个月区间
        let cal = Calendar.current
        let prevStart = cal.date(byAdding: .month, value: -1, to: start) ?? start
        _prevMonthTransactions = Query(
            filter: #Predicate<Transaction> { $0.date >= prevStart && $0.date < start },
            sort: []
        )
    }

    // MARK: 数值

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

    private var balance: Decimal {
        monthIncome - monthExpense
    }

    private var prevExpense: Decimal {
        prevMonthTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var prevIncome: Decimal {
        prevMonthTransactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var prevBalance: Decimal {
        prevIncome - prevExpense
    }

    /// 结余环比变化百分比（上月结余为 0 时无意义，返回 nil）
    private var balanceChangePercent: Double? {
        guard prevBalance != 0 else { return nil }
        let delta = (balance - prevBalance) as NSDecimalNumber
        let base = (prevBalance as NSDecimalNumber).doubleValue
        return delta.doubleValue / abs(base) * 100
    }

    private var currentBudget: Budget? {
        budgets.first { $0.month == monthKey }
    }

    // MARK: 视图

    var body: some View {
        VStack(alignment: .leading, spacing: DSpace.lg) {
            headerRow
            balanceRow
            incomeExpenseRow

            if let budget = currentBudget {
                budgetSection(budget: budget)
            } else {
                noBudgetSection
            }
        }
        .padding(DSpace.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        // UI优化：根据设计稿调整为深色卡片背景
        .background(heroBackground)
        .onAppear {
            withAnimation(AppAnimation.hero) { appeared = true }
        }
    }

    /// 顶部：月份 + 环比标签
    private var headerRow: some View {
        HStack(alignment: .center) {
            Text(DateFormatters.monthTitle(Date()))
                .font(Typography.subheadline)
                // UI优化：深色卡片上文字使用白色
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            if let pct = balanceChangePercent {
                changeChip(percent: pct)
            }
        }
    }

    /// 环比标签：↑ 比上月增长 x% / ↓ 比上月下降 x%
    private func changeChip(percent: Double) -> some View {
        let up = percent >= 0
        let value = Int(abs(percent).rounded())
        let color = up ? DSColor.income : DSColor.expense
        return HStack(spacing: 4) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 10, weight: .bold))
            Text(up ? "比上月增长 \(value)%" : "比上月下降 \(value)%")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, DSpace.md)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.2)))
        .transition(.scale.combined(with: .opacity))
    }

    /// 结余大数字：页面视觉焦点
    private var balanceRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("本月支出")
                .font(.caption)
                // UI优化：深色卡片上文字使用白色
                .foregroundStyle(.white.opacity(0.7))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("¥")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(DateFormatters.money(abs(balance)))
                    .font(Typography.moneyHero)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .animation(AppAnimation.hero, value: appeared)
        }
    }

    /// 收入 / 支出分列
    private var incomeExpenseRow: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DSColor.income.opacity(0.9))
                    Text("预算剩余")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text("¥\(DateFormatters.money(monthIncome - monthExpense))")
                    .font(Typography.moneyTitle)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DSColor.expense.opacity(0.9))
                    Text("日常支出")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text("¥\(DateFormatters.money(monthExpense))")
                    .font(Typography.moneyTitle)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    /// 含预算时的进度区
    private func budgetSection(budget: Budget) -> some View {
        let spent = monthExpense
        let ratio = budget.amount > 0 ? BudgetService.double(spent / budget.amount) : 0
        let remaining = budget.amount - spent
        let over = remaining < 0
        let days = BudgetService.remainingDays(in: monthKey)
        let daily: Decimal? = (remaining > 0 && days > 0) ? remaining / Decimal(days) : nil
        let barColor = over ? DSColor.expense : (statusColor(ratio) == .near ? DSColor.warning : DSColor.healthy)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本月预算")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(BudgetService.percentText(ratio))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(barColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(geo.size.width * CGFloat(min(ratio, 1)), 0))
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                Text(over
                     ? "已超支 ¥\(DateFormatters.money(-remaining))"
                     : "剩余 ¥\(DateFormatters.money(remaining))")
                    .font(.caption)
                    .foregroundStyle(over ? DSColor.expense : .white.opacity(0.6))
                Spacer()
                if let daily {
                    Text("今日建议 ≤ ¥\(DateFormatters.money(daily))")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                // UI优化：预算管理按钮在深色卡片上
                Button {
                    onEditBudget()
                } label: {
                    Text("管理")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(.white.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// 未设置预算时的提示与入口
    private var noBudgetSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("本月预算")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                Text("设置预算，更从容地掌控每月支出")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            // UI优化：设置预算按钮在深色卡片上
            Button {
                onEditBudget()
            } label: {
                Text("设置预算")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.2)))
            }
            .buttonStyle(.plain)
        }
    }

    /// 预算超支判定：ratio > 1 超支、≥0.8 接近、否则正常
    private func statusColor(_ ratio: Double) -> BudgetService.BudgetStatus {
        if ratio > 1 { return .over }
        if ratio >= 0.8 { return .near }
        return .normal
    }

    /// 卡片背景：UI优化 — 根据设计稿使用深色渐变背景
    private var heroBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DRadius.hero, style: .continuous)
                .fill(DSColor.heroCardDark)
            RoundedRectangle(cornerRadius: DRadius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DSColor.primary.opacity(0.25), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: DSColor.primary.opacity(0.15), radius: 20, x: 0, y: 8)
    }
}

import SwiftUI
import SwiftData
import Charts
import UIKit

/// 统计周期
enum StatPeriod: String, CaseIterable, Identifiable {
    case month = "月度"
    case year = "年度"
    var id: String { rawValue }
}

/// 统计报表（仿鲨鱼记账）：月度/年度切换、支出/收入切换、分类排行、占比环图、收支趋势
///
/// 数据源：StatisticsContent 内的 @Query 直接监听 SwiftData 存储，
/// 新增 / 编辑 / 删除交易后统计自动刷新；周期 / 月份 / 年份变化时通过
/// .id(queryKey) 重建查询（@Query 谓词在 init 中构建，无法运行时动态修改）。
struct StatisticsView: View {
    @State private var period: StatPeriod = .month
    @State private var month: Date = Date()
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var showIncome = false

    private var queryKey: String {
        period == .month ? "month-\(DateFormatters.monthKey(month))" : "year-\(year)"
    }

    var body: some View {
        StatisticsContent(
            period: $period,
            month: month,
            year: year,
            showIncome: $showIncome,
            onShiftPeriod: shiftPeriod
        )
        .id(queryKey)
    }

    private func shiftPeriod(_ delta: Int) {
        if period == .month {
            month = Calendar.current.date(byAdding: .month, value: delta, to: month) ?? month
        } else {
            year += delta
        }
    }
}

/// 统计内容：持有全部 @Query 数据源与各图表区块。
private struct StatisticsContent: View {
    @Binding var period: StatPeriod
    let month: Date
    let year: Int
    @Binding var showIncome: Bool
    var onShiftPeriod: (Int) -> Void

    @Query private var budgets: [Budget]

    /// 当前统计周期的流水（谓词限定，避免全量加载；@Query 随数据变化自动更新）
    @Query private var items: [Transaction]

    /// 趋势图所需数据：月度 = 近 6 个月；年度 = 全年
    @Query private var trendItems: [Transaction]

    /// 未分类流水在图表/排行中的聚合键（UUID 哨兵）
    private static let uncategorizedID = UUID()

    init(
        period: Binding<StatPeriod>,
        month: Date,
        year: Int,
        showIncome: Binding<Bool>,
        onShiftPeriod: @escaping (Int) -> Void
    ) {
        self._period = period
        self.month = month
        self.year = year
        self._showIncome = showIncome
        self.onShiftPeriod = onShiftPeriod

        let currentPeriod = period.wrappedValue
        let cal = Calendar.current
        let periodPredicate: Predicate<Transaction>
        let trendPredicate: Predicate<Transaction>

        if currentPeriod == .month {
            let start = cal.dateInterval(of: .month, for: month)?.start ?? month
            let end = cal.date(byAdding: .month, value: 1, to: start) ?? start
            let trendStart = cal.date(byAdding: .month, value: -5, to: start) ?? start
            periodPredicate = #Predicate<Transaction> { $0.date >= start && $0.date < end }
            trendPredicate = #Predicate<Transaction> { $0.date >= trendStart && $0.date < end }
        } else {
            let start = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
            let end = cal.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? Date()
            periodPredicate = #Predicate<Transaction> { $0.date >= start && $0.date < end }
            trendPredicate = periodPredicate
        }

        _items = Query(
            filter: periodPredicate,
            sort: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        _trendItems = Query(filter: trendPredicate)
    }

    private var periodTitle: String {
        period == .month ? DateFormatters.monthTitle(month) : "\(year)年"
    }

    private func shiftPeriod(_ delta: Int) {
        onShiftPeriod(delta)
    }

    private var periodExpense: [Transaction] {
        items.filter { $0.type == .expense }
    }

    private var periodIncome: [Transaction] {
        items.filter { $0.type == .income }
    }

    private var totalExpense: Decimal {
        periodExpense.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var totalIncome: Decimal {
        periodIncome.reduce(Decimal.zero) { $0 + $1.amount }
    }

    private var balance: Decimal {
        totalIncome - totalExpense
    }

    private var currentBudget: Budget? {
        budgets.first { $0.month == DateFormatters.monthKey(month) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                periodSection
                summaryCards
                if period == .month {
                    budgetSection
                }
                pieSection
                rankingSection
                if period == .month {
                    dailyBar
                }
                trendSection
            }
            .padding()
        }
        .background(AppTheme.background)
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 区块：周期切换

    private var periodSection: some View {
        VStack(spacing: 14) {
            Picker("周期", selection: $period) {
                ForEach(StatPeriod.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    shiftPeriod(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)

                Spacer()
                Text(periodTitle)
                    .font(.headline)
                Spacer()

                Button {
                    shiftPeriod(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }

    // MARK: - 区块：收支卡片

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "支出", value: totalExpense, color: AppTheme.expense)
            summaryCard(title: "收入", value: totalIncome, color: AppTheme.income)
            summaryCard(title: "结余", value: balance, color: balance < 0 ? AppTheme.expense : AppTheme.primary)
        }
    }

    private func summaryCard(title: String, value: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("¥\(DateFormatters.money(value))")
                .font(.title3.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - 区块：预算

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本月预算")
                    .font(.headline)
                Spacer()
                Text(budgetSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let budget = currentBudget {
                let ratio = budget.amount > 0 ? totalExpense / budget.amount : Decimal.zero
                let over = totalExpense > budget.amount
                let progress = min(Double((ratio as NSDecimalNumber).doubleValue), 1.0)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.systemGray5))
                        Capsule()
                            .fill(over ? AppTheme.expense : AppTheme.primary)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 10)

                if over {
                    Label(
                        "已超支 ¥\(DateFormatters.money(totalExpense - budget.amount))",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(AppTheme.expense)
                }
            }
        }
        .cardStyle()
    }

    private var budgetSummaryText: String {
        guard let budget = currentBudget else { return "未设置" }
        return "已支出 ¥\(DateFormatters.money(totalExpense)) / ¥\(DateFormatters.money(budget.amount))"
    }

    // MARK: - 区块：支出构成环图

    private struct PieItem: Identifiable {
        let id: UUID
        let name: String
        let icon: String
        let amount: Decimal
    }

    private var pieItems: [PieItem] {
        let dict = Dictionary(grouping: periodExpense) { $0.category?.id ?? Self.uncategorizedID }
        return dict.compactMap { key, group in
            let sum = group.reduce(Decimal.zero) { $0 + $1.amount }
            if key == Self.uncategorizedID {
                // 未分类流水也参与统计，避免环图与总支出对不上
                return PieItem(id: UUID(), name: "未分类", icon: "questionmark", amount: sum)
            }
            guard let cat = group.first?.category else { return nil }
            return PieItem(id: cat.id, name: cat.name, icon: cat.icon, amount: sum)
        }
        .sorted { $0.amount > $1.amount }
    }

    private var pieSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支出构成")
                .font(.headline)

            if pieItems.isEmpty {
                Text("本期暂无支出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(pieItems) { item in
                    SectorMark(
                        angle: .value("金额", double(item.amount)),
                        innerRadius: .ratio(0.62)
                    )
                    .foregroundStyle(ColorPalette.color(for: item.name))
                }
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 4) {
                        Text("支出")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("¥\(DateFormatters.money(totalExpense))")
                            .font(.headline)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 区块：分类排行

    private struct CategoryRank: Identifiable {
        let id: UUID
        let name: String
        let icon: String
        let amount: Decimal
        let percent: Double
    }

    private var ranking: [CategoryRank] {
        let shown = showIncome ? periodIncome : periodExpense
        let total = shown.reduce(Decimal.zero) { $0 + $1.amount }
        let dict = Dictionary(grouping: shown) { $0.category?.id ?? Self.uncategorizedID }
        return dict.compactMap { key, group in
            let sum = group.reduce(Decimal.zero) { $0 + $1.amount }
            let pct = total > 0 ? Double((sum / total as NSDecimalNumber).doubleValue) * 100 : 0
            if key == Self.uncategorizedID {
                // 未分类也进入排行，保证百分比之和为 100%
                return CategoryRank(id: UUID(), name: "未分类", icon: "questionmark", amount: sum, percent: pct)
            }
            guard let cat = group.first?.category else { return nil }
            return CategoryRank(id: cat.id, name: cat.name, icon: cat.icon, amount: sum, percent: pct)
        }
        .sorted { $0.amount > $1.amount }
    }

    private var rankingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("分类排行")
                    .font(.headline)
                Spacer()
                Picker("类型", selection: $showIncome) {
                    Text("支出").tag(false)
                    Text("收入").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if ranking.isEmpty {
                Text("本期暂无数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let maxAmount = ranking.first?.amount ?? 1
                ForEach(ranking) { rank in
                    HStack(spacing: 10) {
                        Image(systemName: rank.icon)
                            .font(.system(size: 16))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(ColorPalette.color(for: rank.name).opacity(0.15)))
                            .foregroundStyle(ColorPalette.color(for: rank.name))

                        Text(rank.name)
                            .font(.subheadline)
                            .frame(width: 52, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.systemGray5))
                                Capsule()
                                    .fill(ColorPalette.color(for: rank.name).opacity(0.8))
                                    .frame(width: geo.size.width * CGFloat(double(rank.amount / maxAmount)))
                            }
                        }
                        .frame(height: 8)

                        Text(String(format: "%.1f%%", rank.percent))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)

                        Text("¥\(DateFormatters.money(rank.amount))")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 84, alignment: .trailing)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 区块：每日支出（月度）

    private struct DayTotal: Identifiable {
        let day: Date
        let amount: Decimal
        var id: Date { day }
    }

    private var dailyExpense: [DayTotal] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: periodExpense) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted().map { day in
            DayTotal(
                day: day,
                amount: dict[day]!.reduce(Decimal.zero) { $0 + $1.amount }
            )
        }
    }

    private var dailyBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每日支出")
                .font(.headline)
            if dailyExpense.isEmpty {
                Text("本月暂无支出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(dailyExpense) { item in
                    BarMark(
                        x: .value("日期", item.day, unit: .day),
                        y: .value("金额", double(item.amount))
                    )
                    .foregroundStyle(AppTheme.primary.opacity(0.8))
                }
                // 横轴显式中文格式（如 8月17日），不随系统语言变成 Aug 17
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day().locale(Locale(identifier: "zh_CN")))
                    }
                }
                .frame(height: 180)
            }
        }
        .cardStyle()
    }

    // MARK: - 区块：收支趋势

    private struct MonthStat: Identifiable {
        let date: Date
        /// 横轴中文月份标签（如 "8月"），直接作为图表文本，不依赖系统 Locale
        let label: String
        let expense: Double
        let income: Double
        var id: Date { date }
    }

    private var trend: [MonthStat] {
        let cal = Calendar.current
        let months: [Date]
        if period == .month {
            months = (0..<6).reversed().compactMap { cal.date(byAdding: .month, value: -$0, to: month) }
        } else {
            months = (1...12).compactMap { m in
                cal.date(from: DateComponents(year: year, month: m, day: 1))
            }
        }
        return months.map { d in
            let start = cal.dateInterval(of: .month, for: d)?.start ?? d
            let end = cal.dateInterval(of: .month, for: d)?.end ?? d
            let monthItems = trendItems.filter { $0.date >= start && $0.date < end }
            let exp = monthItems.filter { $0.type == .expense }.reduce(Decimal.zero) { $0 + $1.amount }
            let inc = monthItems.filter { $0.type == .income }.reduce(Decimal.zero) { $0 + $1.amount }
            return MonthStat(date: d, label: DateFormatters.monthShortTitle(d), expense: double(exp), income: double(inc))
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(period == .month ? "近 6 月收支趋势" : "全年每月收支")
                .font(.headline)
            Chart(trend) { item in
                BarMark(
                    x: .value("月份", item.label),
                    y: .value("金额", item.income)
                )
                .foregroundStyle(by: .value("类型", "收入"))
                BarMark(
                    x: .value("月份", item.label),
                    y: .value("金额", item.expense)
                )
                .foregroundStyle(by: .value("类型", "支出"))
            }
            .chartForegroundStyleScale(["支出": AppTheme.expense, "收入": AppTheme.income])
            // 横轴直接显示中文月份（如 3月/4月/5月…），不随系统语言变成 Mar/Apr
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                }
            }
            .frame(height: 200)
        }
        .cardStyle()
    }

    // MARK: - 工具

    private func double(_ value: Decimal) -> Double {
        (value as NSDecimalNumber).doubleValue
    }
}
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

/// 统计报表：月度/年度切换、支出/收入切换、分类排行、占比环图、收支趋势
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
            VStack(spacing: AppSpacing.l) {
                periodSection
                healthScoreCard
                summaryCard
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
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.s)
        }
        // UI优化：根据设计稿调整背景色
        .background(DSColor.background)
        .navigationTitle("统计")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 区块：周期切换

    private var periodSection: some View {
        VStack(spacing: 14) {
            // UI优化：参考设计稿使用紫色分段控件
            HStack(spacing: 0) {
                ForEach(StatPeriod.allCases) { p in
                    Button {
                        withSmoothAnimation(AppAnimation.spring) {
                            period = p
                        }
                    } label: {
                        Text(p.rawValue)
                            .font(.subheadline.weight(period == p ? .semibold : .regular))
                            .foregroundStyle(period == p ? DSColor.buttonText : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(period == p ? DSColor.primary : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(DSColor.secondaryFill))

            HStack {
                chevronButton("chevron.left") { shiftPeriod(-1) }
                Spacer()
                Text(periodTitle)
                    .font(Typography.headline)
                    .contentTransition(.numericText())
                Spacer()
                chevronButton("chevron.right") { shiftPeriod(1) }
            }
        }
        .cardStyle()
    }

    private func chevronButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(DSColor.secondaryFill))
        }
        .buttonStyle(DSScaleButtonStyle())
    }

    // MARK: - 区块：财务健康评分（UI优化：参考设计稿添加）

    private var healthScoreCard: some View {
        let score = calculateHealthScore()
        return VStack(spacing: 12) {
            HStack {
                Text("财务健康评分")
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(periodTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center, spacing: 16) {
                // 分数显示
                ZStack {
                    Circle()
                        .stroke(DSColor.track, lineWidth: 6)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100.0)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [DSColor.healthy, DSColor.primary]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(score)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("良好")
                            .font(.caption2)
                            .foregroundStyle(DSColor.healthy)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    scoreIndicator(label: "支出控制", score: score)
                    scoreIndicator(label: "预算执行", score: min(score + 5, 100))
                    scoreIndicator(label: "储蓄习惯", score: max(score - 3, 0))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .cardStyle()
    }

    private func scoreIndicator(label: String, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(score)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(score >= 80 ? DSColor.healthy : (score >= 60 ? DSColor.warning : DSColor.expense))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(DSColor.track)
                    Capsule()
                        .fill(score >= 80 ? DSColor.healthy : (score >= 60 ? DSColor.warning : DSColor.expense))
                        .frame(width: geo.size.width * CGFloat(score) / 100.0)
                }
            }
            .frame(height: 4)
        }
    }

    private func calculateHealthScore() -> Int {
        guard let budget = currentBudget, budget.amount > 0 else { return 75 }
        let ratio = NSDecimalNumber(decimal: totalExpense / budget.amount).doubleValue
        if ratio <= 0.7 { return 92 }
        if ratio <= 0.85 { return 85 }
        if ratio <= 1.0 { return 72 }
        return max(40, Int(100 - (ratio - 1.0) * 100))
    }

    // MARK: - 区块：收支汇总卡（一体化）

    private var summaryCard: some View {
        HStack(spacing: 0) {
            DSStatColumn(
                title: "支出",
                value: "¥\(DateFormatters.money(totalExpense))",
                color: DSColor.expense
            )
            DSColumnDivider()
            DSStatColumn(
                title: "收入",
                value: "¥\(DateFormatters.money(totalIncome))",
                color: DSColor.income
            )
            DSColumnDivider()
            DSStatColumn(
                title: "结余",
                value: "¥\(DateFormatters.money(balance))",
                color: balance < 0 ? DSColor.expense : DSColor.primary
            )
        }
        .cardStyle()
    }

    // MARK: - 区块：预算

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("本月预算")
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
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
                        Capsule().fill(DSColor.track)
                        Capsule()
                            .fill(over ? DSColor.expense : DSColor.primary)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)

                if over {
                    Label(
                        "已超支 ¥\(DateFormatters.money(totalExpense - budget.amount))",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(DSColor.expense)
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
            Text("分类占比")
                .font(Typography.headline)
                .foregroundStyle(.primary)

            if pieItems.isEmpty {
                Text("本期暂无支出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    Chart(pieItems) { item in
                        SectorMark(
                            angle: .value("金额", double(item.amount)),
                            innerRadius: .ratio(0.62)
                        )
                        .foregroundStyle(ColorPalette.color(for: item.name))
                    }
                    .frame(width: 120, height: 120)

                    // UI优化：参考设计稿添加图例列表
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(pieItems.prefix(5)) { item in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(ColorPalette.color(for: item.name))
                                    .frame(width: 8, height: 8)
                                Text(item.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "%.1f%%", percentage(item.amount)))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                Text("支出 ¥\(DateFormatters.money(totalExpense))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private func percentage(_ amount: Decimal) -> Double {
        guard totalExpense > 0 else { return 0 }
        return Double((amount / totalExpense as NSDecimalNumber).doubleValue) * 100
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
                Text("支出排行")
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                Spacer()
                // UI优化：参考设计稿使用自定义分段控件
                HStack(spacing: 0) {
                    Button {
                        withSmoothAnimation(AppAnimation.spring) { showIncome = false }
                    } label: {
                        Text("支出")
                            .font(.caption.weight(!showIncome ? .semibold : .regular))
                            .foregroundStyle(!showIncome ? DSColor.buttonText : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(!showIncome ? DSColor.primary : .clear)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        withSmoothAnimation(AppAnimation.spring) { showIncome = true }
                    } label: {
                        Text("收入")
                            .font(.caption.weight(showIncome ? .semibold : .regular))
                            .foregroundStyle(showIncome ? DSColor.buttonText : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                Capsule().fill(showIncome ? DSColor.primary : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(2)
                .frame(width: 120)
                .background(Capsule().fill(DSColor.secondaryFill))
            }

            if ranking.isEmpty {
                Text("本期暂无数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(ranking) { rank in
                    HStack(spacing: 10) {
                        // UI优化：参考设计稿使用圆角方形图标
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(ColorPalette.color(for: rank.name).opacity(0.15))
                                .frame(width: 30, height: 30)
                            Image(systemName: rank.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ColorPalette.color(for: rank.name))
                        }

                        Text(rank.name)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(width: 52, alignment: .leading)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(DSColor.track)
                                Capsule()
                                    .fill(ColorPalette.color(for: rank.name).opacity(0.78))
                                    .frame(width: geo.size.width * CGFloat(double(rank.amount / maxAmount)))
                            }
                        }
                        .frame(height: 7)

                        Text(String(format: "%.1f%%", rank.percent))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .trailing)

                        Text("¥\(DateFormatters.money(rank.amount))")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
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
            Text("支出趋势")
                .font(Typography.headline)
                .foregroundStyle(.primary)
            if dailyExpense.isEmpty {
                Text("本月暂无支出")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(dailyExpense) { item in
                    LineMark(
                        x: .value("日期", item.day, unit: .day),
                        y: .value("金额", double(item.amount))
                    )
                    .foregroundStyle(DSColor.primary)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("日期", item.day, unit: .day),
                        y: .value("金额", double(item.amount))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [DSColor.primary.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                // 横轴显式中文格式（如 8月17日），不随系统语言变成 Aug 17
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(DSColor.track)
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day().locale(Locale(identifier: "zh_CN")))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                            .foregroundStyle(DSColor.track)
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
                .font(Typography.headline)
                .foregroundStyle(.primary)
            Chart(trend) { item in
                BarMark(
                    x: .value("月份", item.label),
                    y: .value("金额", item.income)
                )
                .foregroundStyle(by: .value("类型", "收入"))
                .cornerRadius(3)
                BarMark(
                    x: .value("月份", item.label),
                    y: .value("金额", item.expense)
                )
                .foregroundStyle(by: .value("类型", "支出"))
                .cornerRadius(3)
            }
            .chartForegroundStyleScale(["支出": DSColor.expense, "收入": DSColor.income])
            // 横轴直接显示中文月份（如 3月/4月/5月…），不随系统语言变成 Mar/Apr
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(DSColor.track)
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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

    private var maxAmount: Decimal {
        ranking.first?.amount ?? 1
    }
}

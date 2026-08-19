import SwiftUI
import SwiftData

/// 预算页（成熟记账 App 视觉）：浅灰绿背景 + 青绿渐变大卡 + 大金额 + 状态式进度条
/// + 「今日可用」卖点 + 统计小卡 + 全宽主按钮 + 历史记录。
///
/// 数据源：BudgetContent 内的 @Query 直接监听 SwiftData 存储，
/// 新增 / 编辑 / 删除交易后预算数字自动刷新；切换月份时通过 .id(key) 重建。
struct BudgetView: View {
    @State private var referenceDate: Date = Date()
    @State private var showEdit = false

    private var key: String { DateFormatters.monthKey(referenceDate) }
    private var isCurrentMonth: Bool { key == DateFormatters.monthKey() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    monthSelector

                    BudgetContent(
                        monthKey: key,
                        onShowEdit: { showEdit = true },
                        onOpenMonth: { monthKey in jump(to: monthKey) }
                    )
                    .id(key)
                    .transition(.opacity)
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.s)
                .padding(.bottom, AppSpacing.xxxl)
            }
            // UI优化：根据设计稿调整背景色
            .background(DSColor.background)
            .navigationTitle("预算")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEdit) {
                BudgetEditView(month: key)
            }
        }
    }

    private func shiftMonth(_ delta: Int) {
        guard let shifted = Calendar.current.date(byAdding: .month, value: delta, to: referenceDate) else { return }
        if shifted > Date() { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            referenceDate = shifted
        }
    }

    private func jump(to monthKey: String) {
        guard let start = BudgetService.monthRange(monthKey)?.start else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            referenceDate = start
        }
    }

    // MARK: - 月份选择器

    private var monthSelector: some View {
        HStack(spacing: AppSpacing.m) {
            chevronButton(systemName: "chevron.left") { shiftMonth(-1) }
            Spacer()
            VStack(spacing: 2) {
                Text(BudgetService.monthTitle(key))
                    .font(.system(size: 20, weight: .semibold))
                    .contentTransition(.numericText())
                if !isCurrentMonth {
                    Button("回到本月") {
                        withAnimation(.easeInOut(duration: 0.25)) { referenceDate = Date() }
                    }
                    .font(.caption)
                    .foregroundStyle(DSColor.healthy)
                }
            }
            Spacer()
            chevronButton(systemName: "chevron.right") { shiftMonth(1) }
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.35 : 1)
        }
        .padding(.vertical, AppSpacing.s)
    }

    private func chevronButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(DSColor.cardBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

/// 预算内容：持有全部 @Query 数据源（预算记录 + 全部流水），
/// 月度汇总与历史记录在内存中实时计算，随数据变化自动刷新。
private struct BudgetContent: View {
    let monthKey: String
    var onShowEdit: () -> Void
    var onOpenMonth: (String) -> Void

    @Query(sort: \Budget.month, order: .reverse)
    private var budgets: [Budget]

    /// 全部流水（@Query 随数据变化自动更新；按月份内存聚合）
    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    private var isCurrentMonth: Bool { monthKey == DateFormatters.monthKey() }

    init(monthKey: String, onShowEdit: @escaping () -> Void, onOpenMonth: @escaping (String) -> Void) {
        self.monthKey = monthKey
        self.onShowEdit = onShowEdit
        self.onOpenMonth = onOpenMonth
    }

    /// 每月收支合计（在内存中按月份分组；收入 / 支出按类型区分，
    /// 与 BudgetService 一致：避免在 #Predicate 中使用枚举成员）
    private var totalsByMonth: [String: (expense: Decimal, income: Decimal)] {
        var dict: [String: (expense: Decimal, income: Decimal)] = [:]
        for tx in allTransactions {
            let key = DateFormatters.monthKey(tx.date)
            var entry = dict[key] ?? (.zero, .zero)
            if tx.type == .expense {
                entry.expense += tx.amount
            } else {
                entry.income += tx.amount
            }
            dict[key] = entry
        }
        return dict
    }

    private var summary: BudgetService.MonthSummary {
        let totals = totalsByMonth[monthKey] ?? (.zero, .zero)
        return BudgetService.MonthSummary(
            monthKey: monthKey,
            budget: budgets.first { $0.month == monthKey },
            expense: totals.expense,
            income: totals.income,
            remainingDays: BudgetService.remainingDays(in: monthKey)
        )
    }

    /// 历史预算记录（仅已设置预算的月份，真实支出 / 收入实时计算，按月份倒序）
    private var history: [BudgetService.HistoryItem] {
        budgets
            .filter { $0.amount > 0 }
            .sorted { $0.month > $1.month }
            .prefix(24)
            .compactMap { budget in
                let totals = totalsByMonth[budget.month] ?? (.zero, .zero)
                return BudgetService.HistoryItem(
                    monthKey: budget.month,
                    amount: budget.amount,
                    expense: totals.expense,
                    income: totals.income
                )
            }
    }

    var body: some View {
        Group {
            if summary.isSet {
                heroCard(summary)
            } else {
                emptyStateCard
            }
            dailyAvailableCard(summary)
            statsGrid(summary)
            incomeCard(summary)
            if summary.isSet {
                editButton
            }

            historySection
        }
    }

    // MARK: - 核心预算卡片（柔和层次 · 大额数字）

    @State private var barRevealed = false

    private func heroCard(_ s: BudgetService.MonthSummary) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xl) {
            HStack {
                Text("\(BudgetService.monthTitle(monthKey)) · 本月预算")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DSColor.heroTextSecondary)
                Spacer()
                statusPill(s)
            }

            // 预算金额 = 页面视觉焦点
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("本月预算")
                    .font(.caption)
                    .foregroundStyle(DSColor.heroTextSecondary)
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text("¥")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(DSColor.heroTextPrimary)
                    Text(DateFormatters.money(s.budget?.amount ?? 0))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(DSColor.heroTextPrimary)
                        .contentTransition(.numericText(value: BudgetService.double(s.budget?.amount ?? 0)))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }

            // 状态进度条（视觉上限 100%，文字显示真实比例）
            VStack(spacing: AppSpacing.m) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DSColor.heroHairline)
                        Capsule()
                            .fill(progressColor(s))
                            .frame(width: max(geo.size.width * CGFloat(min(s.ratio, 1.0)) * (barRevealed ? 1 : 0), barRevealed && s.ratio > 0 ? 6 : 0))
                    }
                }
                .frame(height: 10)
                .onAppear {
                    barRevealed = false
                    withAnimation(.easeOut(duration: 0.45)) { barRevealed = true }
                }

                HStack(spacing: 0) {
                    heroStat(title: "已使用", value: BudgetService.percentText(s.ratio), color: progressColor(s))
                    heroDivider
                    heroStat(title: "已支出", value: "¥\(DateFormatters.money(s.expense))", color: .white)
                    heroDivider
                    if s.isOver {
                        heroOverStat(title: "已超支", value: "¥\(DateFormatters.money(-s.remaining))")
                    } else {
                        heroStat(title: "剩余", value: "¥\(DateFormatters.money(s.remaining))", color: .white)
                    }
                }
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        // UI优化：根据设计稿调整为深色卡片背景
        .background(heroBackground)
    }

    private func heroStat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DSColor.heroTextSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private func heroOverStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DSColor.heroTextSecondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DSColor.expense)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(DSColor.heroHairline)
            .frame(width: 1, height: 28)
    }

    private func statusPill(_ s: BudgetService.MonthSummary) -> some View {
        let color = statusColor(s.status)
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(s.isOver ? "本月已超支" : (s.status?.label ?? "预算正常"))
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private func progressColor(_ s: BudgetService.MonthSummary) -> Color {
        if s.isOver { return DSColor.expense }
        if s.status == .near { return DSColor.warning }
        return DSColor.healthy
    }

    private func statusColor(_ status: BudgetService.BudgetStatus?) -> Color {
        switch status {
        case .near: return DSColor.warning
        case .over: return DSColor.expense
        default:    return DSColor.healthy
        }
    }

    /// 预算主卡背景：UI优化 — 根据设计稿使用深色渐变背景
    private var heroBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.xlarge, style: .continuous)
                .fill(DSColor.heroCardDark)
            RoundedRectangle(cornerRadius: AppRadius.xlarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [DSColor.healthy.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .shadow(color: DSColor.healthy.opacity(0.15), radius: 20, x: 0, y: 8)
    }

    // MARK: - 今日可用（视觉重点）

    private func dailyAvailableCard(_ s: BudgetService.MonthSummary) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.l) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(isCurrentMonth ? "今日可用" : "该月结余")
                    .font(.subheadline.weight(.semibold))
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text("¥")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(dailyValueColor(s))
                    Text(dailyValueText(s))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(dailyValueColor(s))
                        .contentTransition(.numericText(value: BudgetService.double(s.dailyAvailable ?? -s.remaining)))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Text(caption(for: s))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isCurrentMonth && !s.isOver ? "calendar" : "exclamationmark.triangle")
                .font(.system(size: 20))
                .foregroundStyle(dailyValueColor(s))
                .frame(width: 48, height: 48)
                .background(Circle().fill(dailyValueColor(s).opacity(0.12)))
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(DSColor.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }

    private func dailyValueText(_ s: BudgetService.MonthSummary) -> String {
        if let daily = s.dailyAvailable {
            return DateFormatters.money(daily)
        }
        if s.isOver {
            return DateFormatters.money(-s.remaining)
        }
        return DateFormatters.money(s.remaining)
    }

    private func dailyValueColor(_ s: BudgetService.MonthSummary) -> Color {
        if s.isOver { return DSColor.expense }
        if s.status == .near { return DSColor.warning }
        return DSColor.healthy
    }

    private func caption(for s: BudgetService.MonthSummary) -> String {
        if isCurrentMonth {
            if s.isOver {
                return "距离月底还有 \(s.remainingDays) 天 · 本月已超支"
            }
            return "距离月底还有 \(s.remainingDays) 天 · 按剩余预算平均计算"
        }
        return "历史月份 · 无每日建议"
    }

    // MARK: - 统计小卡片（本月支出 / 预算使用）

    private func statsGrid(_ s: BudgetService.MonthSummary) -> some View {
        HStack(spacing: AppSpacing.m) {
            statCard(
                title: "本月支出",
                value: "¥\(DateFormatters.money(s.expense))",
                color: DSColor.expense,
                icon: "arrow.down",
                caption: "\(BudgetService.monthTitle(monthKey))累计"
            )
            statCard(
                title: "预算使用",
                value: BudgetService.percentText(s.ratio),
                color: statusColor(s.status),
                icon: s.isOver ? "exclamationmark.triangle" : "chart.bar",
                caption: s.isOver
                    ? "已超支 ¥\(DateFormatters.money(-s.remaining))"
                    : "还剩 ¥\(DateFormatters.money(s.remaining))"
            )
        }
    }

    private func statCard(title: String, value: String, color: Color, icon: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(Circle().fill(color.opacity(0.12)))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText(value: 0))
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(DSColor.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }

    // MARK: - 本月收入（辅助信息，保留功能）

    private func incomeCard(_ s: BudgetService.MonthSummary) -> some View {
        HStack {
            Label("本月收入", systemImage: "arrow.up")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("¥\(DateFormatters.money(s.income))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DSColor.income)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .fill(DSColor.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }

    // MARK: - 主操作（全宽 · 高52 · 圆角16）

    private var editButton: some View {
        Button {
            onShowEdit()
        } label: {
            Text("修改本月预算")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.input + 4)
                        .fill(
                            LinearGradient(
                                colors: [DSColor.healthy, DSColor.primary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: DSColor.healthy.opacity(0.3), radius: 8, y: 4)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 空状态

    private var emptyStateCard: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "target")
                .font(.system(size: 34))
                .foregroundStyle(DSColor.healthy)
                .frame(width: 88, height: 88)
                .background(Circle().fill(DSColor.healthy.opacity(0.12)))

            Text(isCurrentMonth ? "设置你的第一个预算" : "该月暂未设置预算")
                .font(.title3.weight(.semibold))

            Text(isCurrentMonth
                 ? "给自己设一个消费目标，\n更轻松地掌控每个月的支出。"
                 : "为该月设置一个预算，\n之后即可随时回看当月支出使用情况。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
                onShowEdit()
            } label: {
                Text(isCurrentMonth ? "设置本月预算" : "设置该月预算")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppSpacing.xxxl)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.input + 4)
                            .fill(DSColor.healthy)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, AppSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xxxl)
        .padding(.horizontal, AppSpacing.l)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.xlarge)
                .fill(DSColor.cardBackground)
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
    }

    // MARK: - 历史预算记录

    private var historySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("历史预算")
                .font(.headline)

            if history.isEmpty {
                Text("暂无预算记录，设置后会自动出现在这里。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(AppSpacing.l)
                    .background(
                        RoundedRectangle(cornerRadius: AppRadius.card)
                            .fill(DSColor.cardBackground)
                    )
            } else {
                VStack(spacing: 0) {
                    ForEach(history) { item in
                        historyRow(item)
                        if item.id != history.last?.id {
                            Divider().padding(.leading, AppSpacing.l)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.card)
                        .fill(DSColor.cardBackground)
                        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
                )
            }
        }
    }

    private func historyRow(_ item: BudgetService.HistoryItem) -> some View {
        Button {
            onOpenMonth(item.monthKey)
        } label: {
            HStack(spacing: AppSpacing.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(BudgetService.monthTitle(item.monthKey))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("支出 ¥\(DateFormatters.money(item.expense))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.isOver
                         ? "超支 ¥\(DateFormatters.money(item.remaining))"
                         : "剩余 ¥\(DateFormatters.money(item.remaining))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(item.isOver ? DSColor.expense : .primary)
                    Text(BudgetService.percentText(item.ratio))
                        .font(.caption)
                        .foregroundStyle(statusColor(item.status))
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.m)
        }
        .buttonStyle(.plain)
    }
}

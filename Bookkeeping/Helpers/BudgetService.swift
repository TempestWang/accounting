import Foundation
import SwiftData

/// 预算业务逻辑：长期每月预算计算、状态判定、日期区间工具。
///
/// 设计约定：
/// - 预算使用金额始终基于 Transaction 实时计算，不持久化任何中间统计结果；
/// - 一条永久 Budget 记录作为每个月通用的支出上限；
/// - 收入不计入预算使用金额，仅统计 TransactionType.expense；
/// - 预算状态阈值（80% / 100%）统一收敛在本类型，视图不重复硬编码。
enum BudgetService {

    /// 预算状态
    enum BudgetStatus {
        /// 0% ≤ 使用率 < 80%：正常
        case normal
        /// 80% ≤ 使用率 ≤ 100%：接近预算
        case near
        /// 使用率 > 100%：已超预算
        case over

        var label: String {
            switch self {
            case .normal: return "正常"
            case .near:   return "接近预算"
            case .over:   return "已超支"
            }
        }
    }

    /// 某个月份的预算汇总（全部字段实时计算，不持久化）
    struct MonthSummary {
        let monthKey: String
        let budget: Budget?       // nil = 未设置长期每月预算
        let expense: Decimal      // 该月支出合计（仅 expense）
        let income: Decimal       // 该月收入合计（仅 income）
        let remainingDays: Int    // 今天（含）到月底的自然日数；非本月为 0

        /// 是否已设置预算
        var isSet: Bool { (budget?.amount ?? 0) > 0 }

        /// 剩余预算 = 预算 - 支出（负数表示超支）
        var remaining: Decimal {
            guard let amount = budget?.amount, amount > 0 else { return .zero }
            return amount - expense
        }

        /// 使用率（从 0 起，可超过 1 展示真实超支比例）；未设置预算时为 0
        var ratio: Double {
            guard let amount = budget?.amount, amount > 0 else { return 0 }
            return BudgetService.double(expense / amount)
        }

        var isOver: Bool { ratio > 1 }

        /// 状态；未设置预算时为 nil
        var status: BudgetStatus? {
            guard isSet else { return nil }
            if ratio > 1 { return .over }
            if ratio >= 0.8 { return .near }
            return .normal
        }

        /// 今日建议可用金额 = 剩余预算 / 剩余天数；仅当月尚有剩余时有效
        var dailyAvailable: Decimal? {
            let rest = remaining
            guard rest > 0, remainingDays > 0 else { return nil }
            return rest / Decimal(remainingDays)
        }
    }

    /// 历史月度使用项（永久预算 + 当月真实支出 / 收入，实时计算）
    struct HistoryItem: Identifiable {
        let monthKey: String
        let amount: Decimal
        let expense: Decimal
        let income: Decimal

        var id: String { monthKey }

        var remaining: Decimal { amount - expense }
        var ratio: Double { BudgetService.double(expense / amount) }
        var isOver: Bool { ratio > 1 }
        var status: BudgetStatus {
            if ratio > 1 { return .over }
            if ratio >= 0.8 { return .near }
            return .normal
        }
    }

    // MARK: - 数值工具

    /// Decimal → Double（用于进度条 / 百分比计算）
    static func double(_ d: Decimal) -> Double {
        (d as NSDecimalNumber).doubleValue
    }

    /// 使用率展示文本：64%、106.4%；即"n%"或不带多余尾零的一位小数
    static func percentText(_ ratio: Double) -> String {
        let v = ratio * 100
        if v.rounded() == v { return "\(Int(v))%" }
        return String(format: "%.1f%%", v)
    }

    // MARK: - 月份工具

    /// 指定日期所在月份键（形如 "2026-08"）
    static func monthKey(_ date: Date = Date()) -> String {
        DateFormatters.monthKey(date)
    }

    /// 当前日期偏移 n 个月的月份键
    static func monthKey(offset: Int, from date: Date = Date()) -> String {
        let shifted = Calendar.current.date(byAdding: .month, value: offset, to: date) ?? date
        return DateFormatters.monthKey(shifted)
    }

    /// "yyyy-MM" → "2026年8月"
    static func monthTitle(_ key: String) -> String {
        guard let start = monthRange(key)?.start else { return key }
        return DateFormatters.monthTitle(start)
    }

    /// 月份区间 [当月 0 点, 下月 0 点)，全年/跨月不会混淆
    static func monthRange(_ key: String) -> (start: Date, end: Date)? {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let year = Int(parts[0]), let month = Int(parts[1]) else { return nil }
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let start = cal.date(from: comps),
              let end = cal.date(byAdding: .month, value: 1, to: start) else { return nil }
        return (start, end)
    }

    /// 剩余天数：今天（含）到月底的自然日数量；非当前月份返回 0
    static func remainingDays(in key: String, today: Date = Date()) -> Int {
        guard let range = monthRange(key) else { return 0 }
        let cal = Calendar.current
        guard cal.isDate(today, equalTo: range.start, toGranularity: .month) else { return 0 }
        // end 为下月 0 点，今天到 end 的自然日差即"今天（含）至月底"的天数
        let comps = cal.dateComponents([.day], from: today, to: range.end)
        return max(comps.day ?? 0, 1)
    }

    // MARK: - 查询（均需主线程访问 ModelContext）

    /// 返回永久的每月预算。旧版按月记录在首次保存永久预算前仅作为迁移回退值。
    static func permanentBudget(from budgets: [Budget]) -> Budget? {
        if let permanent = budgets.first(where: \.isPermanent) {
            return permanent
        }
        return budgets.sorted { $0.month > $1.month }.first
    }

    /// 从存储中读取永久的每月预算。
    @MainActor
    static func permanentBudget(in context: ModelContext) -> Budget? {
        permanentBudget(from: allBudgets(in: context))
    }

    /// 全部预算记录
    @MainActor
    static func allBudgets(in context: ModelContext) -> [Budget] {
        (try? context.fetch(FetchDescriptor<Budget>())) ?? []
    }

    /// 指定月份收支合计。
    /// 谓词仅用日期区间（捕获的 Date 局部变量，项目已验证可编译），
    /// 支出 / 收入在内存中按类型区分，避免在 #Predicate 中使用枚举成员。
    @MainActor
    static func monthTotals(in monthKey: String, context: ModelContext) -> (expense: Decimal, income: Decimal) {
        guard let range = monthRange(monthKey) else { return (.zero, .zero) }
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate<Transaction> { $0.date >= start && $0.date < end }
        )
        let items = (try? context.fetch(descriptor)) ?? []
        var expense = Decimal.zero
        var income = Decimal.zero
        for item in items {
            if item.type == .expense {
                expense += item.amount
            } else {
                income += item.amount
            }
        }
        return (expense, income)
    }

    /// 某个月的完整预算汇总
    @MainActor
    static func summary(monthKey key: String, context: ModelContext, today: Date = Date()) -> MonthSummary {
        MonthSummary(
            monthKey: key,
            budget: permanentBudget(in: context),
            expense: monthTotals(in: key, context: context).expense,
            income: monthTotals(in: key, context: context).income,
            remainingDays: remainingDays(in: key, today: today)
        )
    }

    /// 历史月度使用情况：每个月都使用同一条永久预算作比较。
    @MainActor
    static func history(in context: ModelContext, limit: Int = 24) -> [HistoryItem] {
        guard let budget = permanentBudget(in: context), budget.amount > 0 else { return [] }
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let keys = Set(transactions.map { monthKey($0.date) })
            .union([monthKey()])
            .sorted(by: >)
            .prefix(limit)
        return keys.map { key in
            let totals = monthTotals(in: key, context: context)
            return HistoryItem(
                monthKey: key,
                amount: budget.amount,
                expense: totals.expense,
                income: totals.income
            )
        }
    }
}

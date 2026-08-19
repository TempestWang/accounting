import Foundation

enum DateFormatters {
    // Formatter 创建开销较大，缓存为静态常量（全部在主线程使用，无需加锁）
    private static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let monthTitleFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月"
        return f
    }()

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f
    }()

    private static let fullDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let monthShortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月"
        return f
    }()

    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    /// 月份键，形如 "2026-08"，用于预算匹配
    static func monthKey(_ date: Date = Date()) -> String {
        monthKeyFormatter.string(from: date)
    }

    /// 月份标题，形如 "2026年8月"
    static func monthTitle(_ date: Date) -> String {
        monthTitleFormatter.string(from: date)
    }

    /// 月份短标题，形如 "8月"，用于图表横坐标（近 6 月收支趋势 / 全年每月收支）
    static func monthShortTitle(_ date: Date) -> String {
        monthShortFormatter.string(from: date)
    }

    /// 短时间，形如 "12:30"，用于列表行的辅助信息
    static func shortTime(_ date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    /// 列表分组标题：今天 / 昨天 / 8月5日 星期三
    static func dayHeader(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        return dayHeaderFormatter.string(from: date)
    }

    /// 金额格式化：千分位 + 两位小数
    static func money(_ value: Decimal) -> String {
        moneyFormatter.string(from: value as NSDecimalNumber) ?? "0.00"
    }

    /// 带符号金额：支出 -¥12.50 / 收入 +¥100.00
    static func signedMoney(_ value: Decimal, type: TransactionType) -> String {
        let sign = type == .expense ? "-" : "+"
        return "\(sign)¥\(money(value))"
    }

    /// 完整日期时间：2026-08-09 13:05
    static func fullDateTime(_ date: Date) -> String {
        fullDateTimeFormatter.string(from: date)
    }
}

import Foundation
import SwiftData

/// 从付款截图文字中解析出的结果
struct ParsedPayment {
    var amount: Decimal?
    var merchant: String?
    var date: Date?
    var type: TransactionType = .expense
    var categoryName: String?
}

/// 启发式解析：从 OCR 文本中提取金额 / 商户 / 日期 / 分类
enum PaymentParser {

    /// 商户关键词 → 分类映射（可按需扩充）
    static let categoryKeywords: [(name: String, keywords: [String])] = [
        ("餐饮", ["星巴克", "瑞幸", "库迪", "美团", "饿了么", "麦当劳", "肯德基", "海底捞", "餐饮", "饭店", "食堂", "外卖", "奶茶", "咖啡", "早餐", "午餐", "晚餐", "小吃", "烧烤", "火锅", "面包", "蛋糕", "餐厅"]),
        ("交通", ["滴滴", "出租车", "地铁", "公交", "高铁", "火车", "加油站", "中国石油", "中国石化", "壳牌", "停车", "etc", "机票", "打车", "单车", "摩拜", "哈啰", "高德打车"]),
        ("购物", ["淘宝", "天猫", "京东", "拼多多", "超市", "便利店", "沃尔玛", "永辉", "山姆", "costco", "商场", "网购", "数码", "手机", "家电", "服饰", "快递"]),
        ("居住", ["房租", "水电", "物业", "燃气", "话费", "宽带", "水费", "电费"]),
        ("娱乐", ["steam", "游戏", "电影", "影院", "ktv", "视频", "会员", "充值", "音乐", "旅行", "旅游", "酒店", "门票", "爱奇艺", "腾讯视频"]),
        ("医疗", ["医院", "药房", "药店", "医疗", "诊所", "体检", "挂号"]),
        ("教育", ["书店", "教育", "培训", "课程", "学费", "文具"]),
    ]

    /// 收入类关键词（命中则判定为收入）
    ///
    /// ⚠️ 不要放裸「收款」「到账」这类词：付款截图里几乎必有
    /// 「收款方 / 收款人 / 收款账号 / 收款码 / 到账账户」等字样，
    /// 命中的话会把明明在花钱的付款截图误判成收入，
    /// 导致「记一笔」预填时默认选中「收入」。
    /// 只保留含义明确的收入信号，如「收入 / 工资 / 收款成功」。
    static let incomeKeywords = ["收入", "进账", "入账", "工资", "奖金", "理财", "利息", "分红", "报销", "收款成功"]

    /// 解析主入口
    static func parse(_ text: String) -> ParsedPayment {
        var result = ParsedPayment()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return result }

        let lower = trimmed.lowercased()
        result.type = incomeKeywords.contains(where: { lower.contains($0.lowercased()) }) ? .income : .expense
        let amountResult = extractAmount(from: trimmed)
        result.amount = amountResult?.value
        // 交易金额前的正负号比页面中的关键词更可靠：
        // 「- ¥100」是支出，「+ ¥100」是收入，即使同一张图还包含“收款方”等文字。
        if let sign = amountResult?.sign {
            result.type = sign == "+" ? .income : .expense
        }
        result.merchant = extractMerchant(from: trimmed)
        result.date = extractDate(from: trimmed)
        result.categoryName = extractCategory(from: trimmed, merchant: result.merchant, type: result.type)
        return result
    }

    /// 在数据库中查找匹配分类；找不到则回退到「其他」
    static func findCategory(named name: String?, type: TransactionType, in context: ModelContext) -> Category? {
        let all = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        if let name, !name.isEmpty, let match = all.first(where: { $0.name == name && $0.type == type }) {
            return match
        }
        return all.first(where: { $0.name == "其他" && $0.type == type })
    }

    // MARK: - 金额

    private struct AmountCandidate {
        let value: Decimal
        let sign: Character?
        let hasSymbol: Bool
        let hasDecimal: Bool
        let isAnchored: Bool
        let isBalance: Bool
    }

    private struct AmountResult {
        let value: Decimal
        let sign: Character?
    }

    private static func extractAmount(from text: String) -> AmountResult? {
        // 先剔除日期与时间文本，避免年份/时间数字被误认为金额（如 "2026-08-09 12:50"）
        let dateStripped = text.replacingOccurrences(
            of: "\\d{4}[-/.年]\\d{1,2}[-/.月]\\d{1,2}日?|\\d{1,2}月\\d{1,2}日|\\d{1,2}:\\d{2}",
            with: " ",
            options: .regularExpression
        )

        // 同时捕获金额前的正负号。OCR 可能把减号识别为 Unicode minus（−）。
        let pattern = "([+\\-−])?\\s*(?:[¥￥]\\s*)?(\\d+(?:[.,]\\d+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = dateStripped as NSString
        let matches = regex.matches(in: dateStripped, range: NSRange(location: 0, length: ns.length))

        let anchors = ["实付", "付款金额", "支付金额", "交易金额", "总额", "金额", "合计", "¥", "￥", "应收", "本金"]
        let balanceWords = ["余额", "剩余", "可用余额", "账户余额", "当前余额"]
        var candidates: [AmountCandidate] = []

        for m in matches {
            let full = ns.substring(with: m.range) as String
            let sign: Character? = m.range(at: 1).location == NSNotFound
                ? nil
                : Character(ns.substring(with: m.range(at: 1)))
            let rawNum = ns.substring(with: m.range(at: 2)) as String
            let numStr = rawNum.replacingOccurrences(of: ",", with: "")
            // 显式指定 POSIX locale，避免德语等地区把 "." 当成千分位导致金额错读
            guard let val = Decimal(string: numStr, locale: Locale(identifier: "en_US_POSIX")), val > 0 else { continue }

            let line = ns.substring(with: ns.lineRange(for: m.range))
            let start = max(0, m.range.location - 24)
            let window = ns.substring(with: NSRange(location: start, length: m.range.location - start))
            let isAnchored = anchors.contains(where: { window.localizedCaseInsensitiveContains($0) })
            let isBalance = balanceWords.contains {
                line.localizedCaseInsensitiveContains($0) || window.localizedCaseInsensitiveContains($0)
            }

            candidates.append(AmountCandidate(
                value: val,
                sign: sign == "−" ? "-" : sign,
                hasSymbol: full.contains("¥") || full.contains("￥"),
                hasDecimal: rawNum.contains(".") || rawNum.contains(","),
                isAnchored: isAnchored,
                isBalance: isBalance
            ))
        }

        // 页面同时出现交易金额与余额时，余额不是可记账金额。
        let usable = candidates.contains(where: { !$0.isBalance })
            ? candidates.filter { !$0.isBalance }
            : candidates
        // 带正负号通常就是交易金额；其后依次按关键词、货币符号、小数格式排序。
        let best = usable.max { lhs, rhs in
            amountScore(lhs) < amountScore(rhs)
        }
        return best.map { AmountResult(value: $0.value, sign: $0.sign) }
    }

    private static func amountScore(_ candidate: AmountCandidate) -> Int {
        (candidate.sign != nil ? 100 : 0)
            + (candidate.isAnchored ? 40 : 0)
            + (candidate.hasSymbol ? 20 : 0)
            + (candidate.hasDecimal ? 10 : 0)
    }

    // MARK: - 商户

    private static let skipMerchantPrefixes = [
        "实付", "付款金额", "支付金额", "金额", "合计", "交易成功", "付款成功",
        "支付成功", "收款成功", "当前状态", "商户全称", "收单机构", "交易单号",
        "商户单号", "付款方", "收款方", "支付时间", "交易时间", "订单", "付款方式",
        "账单", "详情", "支付宝", "微信支付", "云闪付", "收银台", "元", "商品",
    ]

    private static func extractMerchant(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let dateRegex = try? NSRegularExpression(pattern: "\\d{4}[-/.]\\d{1,2}[-/.]\\d{1,2}|\\d{1,2}月\\d{1,2}日")
        let amountRegex = try? NSRegularExpression(pattern: "[¥￥]?\\s*\\d+([.,]\\d{1,2})?")
        let fullLabelWords = ["商户全称", "收款方", "商家名称", "收款方名称", "付款方"]

        var candidates: [String] = []
        for line in lines {
            if line.count > 24 { continue }
            if skipMerchantPrefixes.contains(where: { line.hasPrefix($0) }) { continue }
            // 跳过支付方式行，如「招商银行信用卡(0929)」
            if line.contains("信用卡") || line.contains("储蓄卡") || line.contains("银行卡") { continue }
            // 跳过提示文字
            if line.contains("退款") || line.contains("扫码") { continue }
            // 跳过纯数字 / 金额 / 负数金额
            let clean = line.replacingOccurrences(of: " ", with: "")
            let signStripped = clean.hasPrefix("-") ? String(clean.dropFirst()) : clean
            if signStripped.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "¥" || $0 == "￥" }) { continue }
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            if dateRegex?.firstMatch(in: line, range: fullRange) != nil { continue }
            if let m = amountRegex?.firstMatch(in: line, range: fullRange), m.range.length == fullRange.length { continue }
            candidates.append(line)
        }

        // 页面上出现「商户全称/收款方」等标签时，通常会同时印着完整商户名 → 取最长一行
        let hasFullNameLabel = fullLabelWords.contains { text.contains($0) }
        let picked: String?
        if hasFullNameLabel {
            picked = candidates.max(by: { $0.count < $1.count })
        } else {
            picked = candidates.first
        }
        guard let picked else { return nil }
        return strippedChannelSuffix(from: picked)
    }

    /// 去掉商户名尾部附带的支付渠道名（如「xx美团」「xx饿了么」）
    private static let channelSuffixes = ["美团", "饿了么", "支付宝", "微信支付", "微信"]

    private static func strippedChannelSuffix(from merchant: String) -> String {
        var result = merchant
        for suffix in channelSuffixes {
            // 避免把「美团外卖」误删成「外卖」
            guard result.count - suffix.count >= 3, result.hasSuffix(suffix) else { continue }
            result = String(result.dropLast(suffix.count))
        }
        return result
    }

    // MARK: - 日期

    private static func extractDate(from text: String) -> Date? {
        let patterns = [
            "\\d{4}[-/.年]\\d{1,2}[-/.月]\\d{1,2}日?",
            "\\d{1,2}月\\d{1,2}日",
        ]
        let ns = text as NSString
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let m = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { continue }
            let raw = ns.substring(with: m.range)
            let normalized = raw
                .replacingOccurrences(of: "年", with: "-")
                .replacingOccurrences(of: "月", with: "-")
                .replacingOccurrences(of: "日", with: "")
                .replacingOccurrences(of: ".", with: "-")
                .replacingOccurrences(of: "/", with: "-")

            guard let date = date(fromNormalizedDate: normalized) else { continue }
            return applyingTime(near: m.range, in: text, to: date)
        }
        return nil
    }

    private static func date(fromNormalizedDate normalized: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if normalized.contains("-"), normalized.count >= 8 {
            formatter.dateFormat = "yyyy-M-d"
            return formatter.date(from: normalized)
        }

        // "8月9日" → 补上当前年份
        formatter.dateFormat = "M-d"
        guard let date = formatter.date(from: normalized) else { return nil }
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        let components = DateComponents(
            year: year,
            month: calendar.component(.month, from: date),
            day: calendar.component(.day, from: date)
        )
        return calendar.date(from: components)
    }

    /// 付款凭证常把交易时间紧跟在日期后。日期单独识别成功时，也要保留时分，
    /// 否则记账会默认落在当天 00:00，影响流水顺序。
    private static func applyingTime(near dateRange: NSRange, in text: String, to date: Date) -> Date {
        let patterns = [
            "(?<!\\d)([01]?\\d|2[0-3])\\s*[:：]\\s*([0-5]\\d)(?:\\s*[:：]\\s*([0-5]\\d))?",
            "(?<!\\d)([01]?\\d|2[0-3])\\s*时\\s*([0-5]?\\d)\\s*分?"
        ]

        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = patterns.flatMap { pattern in
            (try? NSRegularExpression(pattern: pattern))?.matches(in: text, range: fullRange) ?? []
        }
        guard let match = matches.min(by: {
            distance(from: $0.range, to: dateRange) < distance(from: $1.range, to: dateRange)
        }), distance(from: match.range, to: dateRange) <= 64,
              let hour = Int(ns.substring(with: match.range(at: 1))),
              let minute = Int(ns.substring(with: match.range(at: 2))) else {
            return date
        }
        let second = match.numberOfRanges > 3 && match.range(at: 3).location != NSNotFound
            ? Int(ns.substring(with: match.range(at: 3))) ?? 0
            : 0
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: second,
            of: date
        ) ?? date
    }

    private static func distance(from timeRange: NSRange, to dateRange: NSRange) -> Int {
        if timeRange.location > dateRange.upperBound {
            return timeRange.location - dateRange.upperBound
        }
        if dateRange.location > timeRange.upperBound {
            return dateRange.location - timeRange.upperBound
        }
        return 0
    }

    // MARK: - 分类

    private static func extractCategory(from text: String, merchant: String?, type: TransactionType) -> String? {
        let haystack = ((merchant ?? "") + " " + text).lowercased()
        for entry in categoryKeywords {
            if entry.keywords.contains(where: { haystack.contains($0.lowercased()) }) {
                return entry.name
            }
        }
        return "其他"
    }
}

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
    static let incomeKeywords = ["收入", "收款", "进账", "工资", "奖金", "理财", "利息", "分红", "报销"]

    /// 解析主入口
    static func parse(_ text: String) -> ParsedPayment {
        var result = ParsedPayment()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return result }

        let lower = trimmed.lowercased()
        result.type = incomeKeywords.contains(where: { lower.contains($0.lowercased()) }) ? .income : .expense
        result.amount = extractAmount(from: trimmed)
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
        let hasSymbol: Bool
        let hasDecimal: Bool
        let isAnchored: Bool
    }

    private static func extractAmount(from text: String) -> Decimal? {
        // 先剔除日期与时间文本，避免年份/时间数字被误认为金额（如 "2026-08-09 12:50"）
        let dateStripped = text.replacingOccurrences(
            of: "\\d{4}[-/.年]\\d{1,2}[-/.月]\\d{1,2}日?|\\d{1,2}月\\d{1,2}日|\\d{1,2}:\\d{2}",
            with: " ",
            options: .regularExpression
        )

        let pattern = "(?:[¥￥]\\s*)?(\\d+(?:[.,]\\d+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = dateStripped as NSString
        let matches = regex.matches(in: dateStripped, range: NSRange(location: 0, length: ns.length))

        let anchors = ["实付", "付款金额", "支付金额", "交易金额", "总额", "金额", "合计", "¥", "￥", "应收", "本金"]
        var candidates: [AmountCandidate] = []

        for m in matches {
            let full = ns.substring(with: m.range) as String
            let rawNum = ns.substring(with: m.range(at: 1)) as String
            let numStr = rawNum.replacingOccurrences(of: ",", with: "")
            // 显式指定 POSIX locale，避免德语等地区把 "." 当成千分位导致金额错读
            guard let val = Decimal(string: numStr, locale: Locale(identifier: "en_US_POSIX")), val > 0 else { continue }

            let start = max(0, m.range.location - 10)
            let window = ns.substring(with: NSRange(location: start, length: m.range.location - start))
            let isAnchored = anchors.contains(where: { window.localizedCaseInsensitiveContains($0) })

            candidates.append(AmountCandidate(
                value: val,
                hasSymbol: full.contains("¥") || full.contains("￥"),
                hasDecimal: rawNum.contains(".") || rawNum.contains(","),
                isAnchored: isAnchored
            ))
        }

        // 优先：金额关键词附近 → 带 ¥ 符号 → 带小数 → 最大
        if let best = candidates.filter(\.isAnchored).map(\.value).max() { return best }
        if let best = candidates.filter(\.hasSymbol).map(\.value).max() { return best }
        if let best = candidates.filter(\.hasDecimal).map(\.value).max() { return best }
        return candidates.map(\.value).max()
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

            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")

            if normalized.contains("-"), normalized.count >= 8 {
                f.dateFormat = "yyyy-M-d"
                if let d = f.date(from: normalized) { return d }
            } else {
                // "8月9日" → 补上当前年份
                f.dateFormat = "M-d"
                if let d = f.date(from: normalized) {
                    let cal = Calendar.current
                    let year = cal.component(.year, from: Date())
                    let comps = DateComponents(year: year, month: cal.component(.month, from: d), day: cal.component(.day, from: d))
                    return cal.date(from: comps)
                }
            }
        }
        return nil
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

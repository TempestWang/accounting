import Foundation
import SwiftData

/// 从付款截图文字中解析出的结果
struct ParsedPayment {
    var amount: Decimal?
    var merchant: String?
    /// 付款页面中除商户名外的商品 / 订单等信息，用于生成备注
    var paymentInfo: String?
    var date: Date?
    var type: TransactionType = .expense
    var categoryName: String?
}

/// 启发式解析：从 OCR 文本中提取金额 / 商户 / 日期 / 分类
enum PaymentParser {

    /// 自动识别和手动编辑共用的备注长度上限。
    static let maxNoteLength = 50

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
    static let incomeKeywords = ["收入", "进账", "工资", "奖金", "理财", "利息", "分红", "报销", "收款成功"]

    /// 解析主入口
    static func parse(_ text: String) -> ParsedPayment {
        var result = ParsedPayment()
        // 后续所有位置索引都基于同一份非空行文本，避免原始 OCR 空行造成金额与字段错配。
        let normalizedText = normalizedLines(from: text).joined(separator: "\n")
        guard !normalizedText.isEmpty else { return result }

        let lower = normalizedText.lowercased()
        result.type = incomeKeywords.contains(where: { lower.contains($0.lowercased()) }) ? .income : .expense
        let amountResult = extractAmount(from: normalizedText)
        result.amount = amountResult?.value
        // 交易金额前的正负号比页面中的关键词更可靠：
        // 「- ¥100」是支出，「+ ¥100」是收入，即使同一张图还包含“收款方”等文字。
        if let sign = amountResult?.sign {
            result.type = sign == "+" ? .income : .expense
        }
        result.merchant = extractMerchant(from: normalizedText, amountLineIndex: amountResult?.lineIndex)
        result.paymentInfo = extractPaymentInfo(
            from: normalizedText,
            merchant: result.merchant,
            amountLineIndex: amountResult?.lineIndex
        )
        result.date = extractDate(from: normalizedText)
        result.categoryName = extractCategory(from: normalizedText, merchant: result.merchant, type: result.type)
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
        let isTransactionAnchor: Bool
        let lineIndex: Int
    }

    private struct AmountResult {
        let value: Decimal
        let sign: Character?
        let lineIndex: Int
    }

    private static func extractAmount(from text: String) -> AmountResult? {
        // 先剔除日期与时间文本，避免年份/时间数字被误认为金额（如 "2026-08-09 12:50"）
        let dateStripped = text.replacingOccurrences(
            of: "\\d{4}[-/.年]\\d{1,2}[-/.月]\\d{1,2}日?|\\d{1,2}月\\d{1,2}日|\\d{1,2}:\\d{2}",
            with: " ",
            options: .regularExpression
        )

        // 同时捕获金额前的正负号。OCR 可能把减号识别为 Unicode minus（−）。
        // 这里只允许同行空格；`\\s` 会吞掉换行，让金额的行号落到上一行。
        let pattern = "([+\\-−])?[ \\t]*(?:[¥￥][ \\t]*)?(\\d+(?:[.,]\\d+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = dateStripped as NSString
        let matches = regex.matches(in: dateStripped, range: NSRange(location: 0, length: ns.length))

        let anchors = ["实付", "实际支付", "付款金额", "支付金额", "交易金额", "交易地金额", "总额", "金额", "合计", "¥", "￥", "应收", "本金"]
        let transactionAnchors = ["实付", "实际支付", "付款金额", "支付金额", "交易金额", "交易地金额"]
        let balanceWords = ["余额", "剩余", "可用余额", "账户余额", "当前余额", "可用额度"]
        let nonTransactionWords = ["标价", "原价", "单价", "汇率", "折扣", "优惠", "立减", "积分", "手续费"]
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
            let isTransactionAnchor = transactionAnchors.contains {
                line.localizedCaseInsensitiveContains($0) || window.localizedCaseInsensitiveContains($0)
            }
            let isBalance = balanceWords.contains {
                line.localizedCaseInsensitiveContains($0) || window.localizedCaseInsensitiveContains($0)
            }
            let isNonTransaction = nonTransactionWords.contains {
                line.localizedCaseInsensitiveContains($0) || window.localizedCaseInsensitiveContains($0)
            }

            candidates.append(AmountCandidate(
                value: val,
                sign: sign == "−" ? "-" : sign,
                hasSymbol: full.contains("¥") || full.contains("￥"),
                hasDecimal: rawNum.contains(".") || rawNum.contains(","),
                isAnchored: isAnchored,
                isBalance: isBalance || isNonTransaction,
                isTransactionAnchor: isTransactionAnchor,
                lineIndex: lineIndex(of: m.range, in: ns)
            ))
        }

        // 页面同时出现交易金额与余额时，余额不是可记账金额。
        let usable = candidates.contains(where: { !$0.isBalance })
            ? candidates.filter { !$0.isBalance }
            : candidates
        // 通知页可能连续展示多张交易卡。交易金额标签最可靠，默认取最后一张卡片的金额。
        let best: AmountCandidate?
        if let lastTransaction = usable.filter({ $0.isTransactionAnchor }).max(by: { $0.lineIndex < $1.lineIndex }) {
            best = lastTransaction
        } else if let signed = usable.filter({ $0.sign != nil }).max(by: { $0.lineIndex < $1.lineIndex }) {
            // 没有字段标签时，带正负号的金额通常是支付卡片主金额。
            best = signed
        } else {
            best = usable.max { lhs, rhs in
                let leftScore = amountScore(lhs)
                let rightScore = amountScore(rhs)
                return leftScore == rightScore ? lhs.lineIndex < rhs.lineIndex : leftScore < rightScore
            }
        }
        return best.map { AmountResult(value: $0.value, sign: $0.sign, lineIndex: $0.lineIndex) }
    }

    private static func amountScore(_ candidate: AmountCandidate) -> Int {
        (candidate.sign != nil ? 100 : 0)
            + (candidate.isAnchored ? 40 : 0)
            + (candidate.hasSymbol ? 20 : 0)
            + (candidate.hasDecimal ? 10 : 0)
    }

    private static func lineIndex(of range: NSRange, in text: NSString) -> Int {
        let prefix = text.substring(with: NSRange(location: 0, length: range.location))
        return prefix.reduce(into: 0) { count, character in
            if character == "\n" { count += 1 }
        }
    }

    // MARK: - 商户

    private static let skipMerchantPrefixes = [
        "实付", "付款金额", "支付金额", "金额", "合计", "交易成功", "付款成功",
        "支付成功", "收款成功", "当前状态", "商户全称", "收单机构", "交易单号",
        "商户单号", "付款方", "收款方", "支付时间", "交易时间", "订单", "付款方式",
        "账单", "详情", "支付宝", "微信支付", "云闪付", "收银台", "元", "商品",
    ]

    private static func extractMerchant(from text: String, amountLineIndex: Int?) -> String? {
        let lines = normalizedLines(from: text)

        let dateRegex = try? NSRegularExpression(pattern: "\\d{4}[-/.]\\d{1,2}[-/.]\\d{1,2}|\\d{1,2}月\\d{1,2}日")
        let amountRegex = try? NSRegularExpression(pattern: "[¥￥]?\\s*\\d+([.,]\\d{1,2})?")
        // 先匹配较长标签，避免「收款方」截断「收款方名称」的值。
        let fullLabelWords = [
            "商户全称", "收款方全称", "商家名称", "收款方名称",
            "交易商户", "交易商家", "收款方", "商户"
        ].sorted { $0.count > $1.count }

        // 付款详情页通常是“标签 + 值”结构。多张通知卡同时出现时，取最下面一张卡片的标签。
        let labeledLines = lines.enumerated().compactMap { index, line -> (index: Int, label: String)? in
            guard let label = fullLabelWords.first(where: { line.hasPrefix($0) }) else { return nil }
            return (index, label)
        }.sorted {
            guard let amountLineIndex else { return $0.index > $1.index }
            let leftDistance = abs($0.index - amountLineIndex)
            let rightDistance = abs($1.index - amountLineIndex)
            return leftDistance == rightDistance ? $0.index > $1.index : leftDistance < rightDistance
        }

        // 交易明细标题是用户希望保留的渠道 + 商户描述。
        if let description = transactionDescription(in: lines, before: amountLineIndex) {
            return strippedChannelSuffix(from: description)
        }

        // “账单详情”页常把商户标题直接放在金额上方，优先取该标题，避免被后续跨列值干扰。
        if labeledLines.isEmpty, let amountLineIndex, amountLineIndex > 0 {
            let title = lines[amountLineIndex - 1]
            if isPlausibleMerchant(title), !title.contains("详情") {
                return strippedChannelSuffix(from: title)
            }
        }

        for labeledLine in labeledLines {
            let lineIndex = labeledLine.index
            let label = labeledLine.label
            let line = lines[lineIndex]
            let value = value(after: label, in: line)
            if let value, isPlausibleMerchant(value) {
                return strippedChannelSuffix(from: completedWrappedValue(value, after: lineIndex, in: lines))
            }
            if let mapped = mappedDetailValue(for: lineIndex, in: lines), isPlausibleMerchant(mapped) {
                return strippedChannelSuffix(from: mapped)
            }
            if lineIndex + 1 < lines.count {
                if let next = wrappedValue(after: lineIndex, in: lines), isPlausibleMerchant(next) {
                    return strippedChannelSuffix(from: next)
                }
            }
        }

        // 微信支付列表页没有“商户全称”标签，卡片左上角的用户会独占一行，且位于金额前。
        if let amountLineIndex {
            let upperBound = min(amountLineIndex, lines.count)
            if let description = lines[..<upperBound].reversed().first(where: { line in
                channelPrefixes.contains { line.hasPrefix($0) }
            }) {
                return strippedChannelSuffix(from: transactionDescription(description))
            }
            for index in stride(from: min(amountLineIndex - 1, lines.count - 1), through: 0, by: -1) {
                let line = lines[index]
                if isStandaloneCardMerchant(line) {
                    // 列表卡片标题本身就是备注描述，例如“支付宝-西安曲江新区运来湘味快餐店”。
                    return line
                }
            }
        }

        var candidates: [String] = []
        for line in lines {
            if line.count > 80 { continue }
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
        let hasFullNameLabel = lines.contains { line in
            fullLabelWords.contains { line.hasPrefix($0) }
        }
        let picked: String?
        if hasFullNameLabel {
            picked = candidates.max(by: { $0.count < $1.count })
        } else {
            picked = candidates.first
        }
        guard let picked else { return nil }
        return strippedChannelSuffix(from: picked)
    }

    private static func normalizedLines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// OCR 可能把括号中的商户后缀拆到下一行；只在括号未闭合时合并，避免把后续页面文字拼进商户名。
    private static func wrappedValue(after index: Int, in lines: [String]) -> String? {
        guard index + 1 < lines.count else { return nil }
        var result = lines[index + 1]
        var nextIndex = index + 2
        while nextIndex < lines.count && hasUnclosedParenthesis(in: result) {
            result += lines[nextIndex]
            nextIndex += 1
        }
        return result
    }

    private static func completedWrappedValue(_ value: String, after index: Int, in lines: [String]) -> String {
        guard hasUnclosedParenthesis(in: value) else { return value }
        var result = value
        var nextIndex = index + 1
        while nextIndex < lines.count && hasUnclosedParenthesis(in: result) {
            result += lines[nextIndex]
            nextIndex += 1
        }
        return result
    }

    private static func hasUnclosedParenthesis(in value: String) -> Bool {
        let opening = value.reduce(into: 0) { count, character in
            if character == "(" || character == "（" { count += 1 }
            if character == ")" || character == "）" { count -= 1 }
        }
        return opening > 0
    }

    private static func value(after label: String, in line: String) -> String? {
        guard let range = line.range(of: label) else { return nil }
        let value = line[range.upperBound...]
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":：-")))
        return value.isEmpty ? nil : value
    }

    private static func isPlausibleMerchant(_ value: String) -> Bool {
        let clean = strippedChannelSuffix(from: value.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !clean.isEmpty, clean.count <= 80 else { return false }
        if skipMerchantPrefixes.contains(where: { clean.hasPrefix($0) }) { return false }
        if clean.contains("信用卡") || clean.contains("储蓄卡") || clean.contains("银行卡") { return false }
        let compact = clean.replacingOccurrences(of: " ", with: "")
        if compact.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "+" || $0 == "-" || $0 == "−" || $0 == "¥" || $0 == "￥" }) {
            return false
        }
        return true
    }

    private static func isStandaloneCardMerchant(_ value: String) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = strippedChannelSuffix(from: clean)
        guard isPlausibleMerchant(clean), normalized.count >= 2 else { return false }
        if normalized.contains(":") || normalized.contains("：") { return false }
        if normalized.contains("支付") || normalized.contains("付款") || normalized.contains("收款") { return false }
        if normalized.contains("交易") || normalized.contains("账单") || normalized.contains("详情") { return false }
        if normalized.contains("服务") || normalized.contains("通知") || normalized.contains("状态") { return false }
        if normalized.contains("入账") || normalized.contains("成功") || normalized.contains("失败") || normalized.contains("进行中") { return false }
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        return !compact.allSatisfy { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" || $0 == "¥" || $0 == "￥" }
    }

    // MARK: - 付款详情 / 备注

    private static let paymentInfoLabels = ["商品说明", "商品", "订单说明", "交易说明", "交易内容", "商品名称"]
        .sorted { $0.count > $1.count }

    private static func extractPaymentInfo(
        from text: String,
        merchant: String?,
        amountLineIndex: Int?
    ) -> String? {
        let lines = normalizedLines(from: text)
        let labelEntries = lines.enumerated().compactMap { index, line -> (index: Int, label: String)? in
            guard let label = paymentInfoLabels.first(where: { line == $0 || line.hasPrefix($0) }) else { return nil }
            return (index, label)
        }
        let orderedEntries = labelEntries.sorted {
            guard let amountLineIndex else { return $0.index > $1.index }
            let leftDistance = abs($0.index - amountLineIndex)
            let rightDistance = abs($1.index - amountLineIndex)
            return leftDistance == rightDistance ? $0.index > $1.index : leftDistance < rightDistance
        }
        for entry in orderedEntries {
            let line = lines[entry.index]
            if let inline = value(after: entry.label, in: line), isUsefulPaymentInfo(inline, merchant: merchant) {
                return inline
            }

            // 标签和值是两列时，以支付时间/交易时间对应的日期作为值区块起点，按列偏移取商品值。
            if let mapped = mappedDetailValue(for: entry.index, in: lines),
               isUsefulPaymentInfo(mapped, merchant: merchant) {
                return mapped
            }

            // 兼容标签和值交错、或标签后紧跟值的 OCR 顺序。
            if entry.index + 1 < lines.count {
                let next = lines[entry.index + 1]
                if isUsefulPaymentInfo(next, merchant: merchant),
                   !paymentInfoLabels.contains(where: { next == $0 || next.hasPrefix($0) }) {
                    return next
                }
            }
        }

        // 交易明细没有“商品”字段，卡片标题本身就是用户希望保留的备注描述。
        if let description = transactionDescription(in: lines, before: amountLineIndex) {
            return description
        }
        return nil
    }

    private static func mappedDetailValue(for labelIndex: Int, in lines: [String]) -> String? {
        guard let timeLabelIndex = lines[...labelIndex].lastIndex(where: {
            $0 == "支付时间" || $0 == "交易时间" || $0.hasPrefix("支付时间") || $0.hasPrefix("交易时间")
        }) else { return nil }

        guard let dateIndex = lines.indices.first(where: { $0 > timeLabelIndex && isDateLike(lines[$0]) }) else {
            return nil
        }
        let candidateIndex = dateIndex + (labelIndex - timeLabelIndex)
        guard lines.indices.contains(candidateIndex), candidateIndex != dateIndex else { return nil }
        return lines[candidateIndex]
    }

    private static func isDateLike(_ value: String) -> Bool {
        let pattern = "\\d{4}[-/.年]\\d{1,2}[-/.月]\\d{1,2}日?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let ns = value as NSString
        return regex.firstMatch(in: value, range: NSRange(location: 0, length: ns.length)) != nil
    }

    private static func transactionDescription(in lines: [String], before amountLineIndex: Int?) -> String? {
        let upperBound = min(amountLineIndex ?? lines.count, lines.count)
        guard let index = lines[..<upperBound].lastIndex(where: { line in
            channelPrefixes.contains { line.hasPrefix($0) }
        }) else { return nil }
        var title = lines[index]
        if hasUnclosedParenthesis(in: title), index + 1 < lines.count {
            title += lines[index + 1]
        }
        return transactionDescription(title)
    }

    private static func transactionDescription(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let parenthesisIndexes = [clean.firstIndex(of: "（"), clean.firstIndex(of: "(")].compactMap { $0 }
        guard let first = parenthesisIndexes.min() else { return clean }
        return String(clean[..<first]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isUsefulPaymentInfo(_ value: String, merchant: String?) -> Bool {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.count <= 120 else { return false }
        if clean == merchant { return false }
        if clean.contains("交易时间") || clean.contains("支付方式") || clean.contains("商户全称") { return false }
        return true
    }

    /// 统一的备注格式：有商品 / 订单信息时优先使用商品，否则使用交易标题或商户名。
    static func composedNote(merchant: String?, paymentInfo: String?) -> String {
        let cleanMerchant = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleanPaymentInfo = paymentInfo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let selected = cleanPaymentInfo.isEmpty ? cleanMerchant : cleanPaymentInfo
        return String(selected.prefix(maxNoteLength))
    }

    /// 去掉商户名附带的支付渠道前后缀（如「支付宝-xx」「xx美团」）。
    private static let channelPrefixes = ["支付宝-", "支付宝：", "微信支付-", "微信支付：", "拼多多支付-", "拼多多支付："]
    private static let channelSuffixes = ["美团", "饿了么", "支付宝", "微信支付", "微信"]

    private static func strippedChannelSuffix(from merchant: String) -> String {
        var result = merchant
        for prefix in channelPrefixes where result.hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
            break
        }
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

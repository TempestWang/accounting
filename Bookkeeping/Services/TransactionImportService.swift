import Foundation
import SwiftData

/// 账单导入服务：识别结果 → 待确认账单 → 正式 Transaction 的唯一转换通道。
///
/// 职责边界：
/// - 由识别结果创建 PendingTransaction（识别数据绝不直接写入正式账单）；
/// - 用户确认后，将 PendingTransaction 转换为正式 Transaction 并删除草稿；
/// - 放弃时删除草稿（不产生任何正式账单）。
enum TransactionImportService {

    // MARK: - 创建待确认账单

    /// 由解析结果创建待确认账单。
    /// 部分字段允许为空：缺失字段由用户在确认页补充；needsReview 标记需核对。
    @MainActor
    static func createPending(
        from parsed: ParsedPayment,
        screenshot: Data?,
        source: String,
        in context: ModelContext
    ) -> PendingTransaction {
        let merchant = parsed.merchant ?? ""
        let categoryName = parsed.categoryName ?? ""
        let needsReview = (parsed.amount == nil || merchant.isEmpty || categoryName.isEmpty)

        let pending = PendingTransaction(
            amount: parsed.amount ?? 0,
            type: parsed.type,
            merchant: merchant,
            categoryName: categoryName,
            date: parsed.date ?? Date(),
            // 待确认页单独展示商户字段，备注先保存付款详情；最终保存时再与商户合并。
            note: parsed.paymentInfo ?? "",
            source: source,
            screenshotData: screenshot,
            needsReview: needsReview
        )
        context.insert(pending)
        try? context.save()
        return pending
    }

    /// 手动录入兜底：完全空白的待确认账单（OCR 失败后用户手动补全）。
    @MainActor
    static func createBlankPending(source: String, in context: ModelContext) -> PendingTransaction {
        let pending = PendingTransaction(
            amount: 0,
            type: .expense,
            source: source,
            needsReview: true
        )
        context.insert(pending)
        try? context.save()
        return pending
    }

    // MARK: - 待确认账单查询

    /// 全部待确认账单（按创建时间倒序，新识别的最先处理）
    @MainActor
    static func allPending(in context: ModelContext) -> [PendingTransaction] {
        (try? context.fetch(FetchDescriptor<PendingTransaction>()))?
            .sorted { $0.createdAt > $1.createdAt } ?? []
    }

    // MARK: - 确认保存 → 正式 Transaction

    /// 用户确认后保存为正式账单：
    /// 1. 校验金额（必须 > 0）；
    /// 2. 按分类名匹配现有 Category（找不到则回退「其他」）；
    /// 3. 创建 Transaction（商户与备注合并进 note，与现有记账行为一致）；
    /// 4. 删除对应待确认账单。
    @MainActor
    static func confirmAndSave(
        _ pending: PendingTransaction,
        amount: Decimal,
        type: TransactionType,
        merchant: String,
        categoryName: String,
        date: Date,
        note: String,
        in context: ModelContext
    ) throws -> Transaction {
        guard amount > 0 else {
            throw ImportError.invalidAmount
        }

        // 分类：优先按名称匹配当前类型下的现有分类，找不到则回退「其他」
        let category = PaymentParser.findCategory(
            named: categoryName.isEmpty ? nil : categoryName,
            type: type,
            in: context
        )

        // 商户与备注合并：保持「note 同时承载商户与备注」的现有数据约定
        let mergedNote = PaymentParser.composedNote(merchant: merchant, paymentInfo: note)

        let transaction = Transaction(
            amount: amount,
            date: date,
            note: mergedNote,
            type: type,
            category: category,
            source: pending.source
        )
        context.insert(transaction)
        context.delete(pending)
        try context.save()
        return transaction
    }

    /// 放弃本次识别：删除待确认账单，不产生任何正式账单。
    @MainActor
    static func discard(_ pending: PendingTransaction, in context: ModelContext) {
        context.delete(pending)
        try? context.save()
    }

    // MARK: - 转换为现有「记一笔」页面的预填数据

    /// 薄适配层：将待确认账单转换为现有 TransactionFormView 的 PrefillData。
    /// 商户和付款详情合并放入 note（与 ImageRecognitionView 一致），
    /// 分类名交给记一笔页面按名称匹配现有分类。
    static func prefillData(from pending: PendingTransaction) -> PrefillData {
        PrefillData(
            amountText: pending.amount > 0 ? "\(pending.amount)" : "",
            note: PaymentParser.composedNote(merchant: pending.merchant, paymentInfo: pending.note),
            categoryName: pending.categoryName.isEmpty ? nil : pending.categoryName,
            date: pending.date,
            type: pending.type,
            source: pending.source
        )
    }

    // MARK: - 金额解析（与交易表单同一套规则）

    /// 解析金额文本：POSIX locale、>0、最多 9 位整数 + 2 位小数
    static func parseAmount(_ text: String) -> Decimal? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let intPart = cleaned.split(separator: ".", omittingEmptySubsequences: false).first ?? ""
        let fracPart = cleaned.contains(".") ? String(cleaned.split(separator: ".", omittingEmptySubsequences: false)[1]) : ""
        guard let amount = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")),
              amount > 0,
              intPart.count <= 9,
              fracPart.count <= 2 else {
            return nil
        }
        return amount
    }

    // MARK: - 错误

    enum ImportError: LocalizedError {
        case invalidAmount

        var errorDescription: String? {
            switch self {
            case .invalidAmount:
                return "金额必须大于 0，无法保存。"
            }
        }
    }
}

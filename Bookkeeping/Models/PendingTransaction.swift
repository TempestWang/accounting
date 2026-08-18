import Foundation
import SwiftData

/// 待确认账单：快捷指令 / OCR / AI 的识别结果先落在这里，
/// **绝不直接写入正式 Transaction**，必须经用户在确认页核对、修改并点击保存后才转换。
///
/// 允许部分字段为空（识别不完整），由用户在确认页补充；
/// 金额为空 / <= 0 时禁止保存为正式账单。
@Model
final class PendingTransaction {
    // CloudKit 兼容要求：所有属性必须为可选或带默认值，且不能用 @Attribute(.unique)
    var id: UUID = UUID()
    /// 金额（识别结果，用户可修改）
    var amount: Decimal = 0
    /// 收支类型（默认支出）
    var type: TransactionType = TransactionType.expense
    /// 商户
    var merchant: String = ""
    /// 识别出的分类名（确认时映射到现有 Category；空 = 待用户选择）
    var categoryName: String = ""
    /// 交易日期（识别失败时默认今天）
    var date: Date = Date()
    /// 备注
    var note: String = ""
    /// 来源：快捷指令截图 / 分享识别 / 手动
    var source: String = "快捷指令识别"
    /// 原始截图（可选，保存后供确认页对照）
    var screenshotData: Data?
    /// 标记存在未识别 / 不确定字段，需要用户重点核对
    var needsReview: Bool = false
    /// 创建时间（用于待确认列表排序）
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        amount: Decimal,
        type: TransactionType,
        merchant: String = "",
        categoryName: String = "",
        date: Date = Date(),
        note: String = "",
        source: String = "快捷指令识别",
        screenshotData: Data? = nil,
        needsReview: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.type = type
        self.merchant = merchant
        self.categoryName = categoryName
        self.date = date
        self.note = note
        self.source = source
        self.screenshotData = screenshotData
        self.needsReview = needsReview
        self.createdAt = createdAt
    }
}
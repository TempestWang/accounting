import Foundation
import SwiftData

/// 一条记账流水
@Model
final class Transaction {
    // CloudKit 兼容要求：所有属性必须为可选或带默认值，且不能用 @Attribute(.unique)
    // （UUID 由 init 生成，唯一性由构造保证，无需数据库约束）
    var id: UUID = UUID()
    var amount: Decimal = 0
    var date: Date = Date()
    var note: String = ""
    var type: TransactionType = TransactionType.expense
    var category: Category?
    /// 来源：手动 / 快捷指令自动记账 / 分享识别
    var source: String = "手动"

    init(
        id: UUID = UUID(),
        amount: Decimal,
        date: Date = Date(),
        note: String = "",
        type: TransactionType = .expense,
        category: Category? = nil,
        source: String = "手动"
    ) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
        self.type = type
        self.category = category
        self.source = source
    }
}

import Foundation
import SwiftData

/// 每月支出预算
@Model
final class Budget {
    // CloudKit 兼容要求：所有属性必须为可选或带默认值，且不能用 @Attribute(.unique)
    // （同月唯一性由 BudgetEditView 的"先查后插"逻辑保证）
    var id: UUID = UUID()
    /// 形如 "2026-08"
    var month: String = ""
    var amount: Decimal = 0

    init(id: UUID = UUID(), month: String, amount: Decimal) {
        self.id = id
        self.month = month
        self.amount = amount
    }
}

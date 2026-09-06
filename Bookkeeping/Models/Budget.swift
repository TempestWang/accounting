import Foundation
import SwiftData

/// 每月支出预算。金额作为长期默认值，应用于每一个自然月。
@Model
final class Budget {
    // CloudKit 兼容要求：所有属性必须为可选或带默认值，且不能用 @Attribute(.unique)。
    var id: UUID = UUID()
    /// 兼容旧版按月预算数据；永久预算使用 "permanent"。
    var month: String = ""
    var amount: Decimal = 0
    /// 为 true 时表示长期有效的每月预算。
    var isPermanent: Bool = false

    init(id: UUID = UUID(), month: String = "permanent", amount: Decimal, isPermanent: Bool = true) {
        self.id = id
        self.month = month
        self.amount = amount
        self.isPermanent = isPermanent
    }
}

import Foundation
import SwiftData

/// 记账分类
@Model
final class Category {
    // CloudKit 兼容要求：所有属性必须为可选或带默认值，且不能用 @Attribute(.unique)
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbol 名称
    var icon: String = ""
    var type: TransactionType = TransactionType.expense
    var sortOrder: Int = 0
    var isBuiltin: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        type: TransactionType,
        sortOrder: Int,
        isBuiltin: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.type = type
        self.sortOrder = sortOrder
        self.isBuiltin = isBuiltin
    }
}

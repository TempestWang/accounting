import Foundation
import SwiftData

/// 记账分类
@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    /// SF Symbol 名称
    var icon: String = ""
    var type: TransactionType = TransactionType.expense
    var sortOrder: Int = 0
    var isBuiltin: Bool = false
    /// 内置分类删除标记：保留墓碑，避免启动播种或备份恢复后重新出现。
    /// `deletionMarker` 避免与 SwiftData 的内部删除状态重名。
    var deletionMarker: Bool = false
    var isDeleted: Bool {
        get { deletionMarker }
        set { deletionMarker = newValue }
    }

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        type: TransactionType,
        sortOrder: Int,
        isBuiltin: Bool = false,
        isDeleted: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.type = type
        self.sortOrder = sortOrder
        self.isBuiltin = isBuiltin
        self.isDeleted = isDeleted
    }
}

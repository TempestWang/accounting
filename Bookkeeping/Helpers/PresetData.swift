import Foundation
import SwiftData

/// 内置默认分类的种子数据
enum PresetData {
    struct Builtin {
        let name: String
        let icon: String
        let type: TransactionType
    }

    static let builtins: [Builtin] = [
        // 支出
        .init(name: "餐饮", icon: "fork.knife", type: .expense),
        .init(name: "交通", icon: "car.fill", type: .expense),
        .init(name: "购物", icon: "bag.fill", type: .expense),
        .init(name: "居住", icon: "house.fill", type: .expense),
        .init(name: "娱乐", icon: "gamecontroller.fill", type: .expense),
        .init(name: "医疗", icon: "cross.case.fill", type: .expense),
        .init(name: "教育", icon: "book.fill", type: .expense),
        .init(name: "其他", icon: "ellipsis.circle.fill", type: .expense),
        // 收入
        .init(name: "工资", icon: "banknote.fill", type: .income),
        .init(name: "奖金", icon: "trophy.fill", type: .income),
        .init(name: "理财", icon: "chart.line.uptrend.xyaxis", type: .income),
        .init(name: "其他", icon: "ellipsis.circle.fill", type: .income),
    ]

    /// 按名称+类型逐项补齐内置分类（幂等）。
    /// 相比"count == 0 才播种"：iCloud 多设备场景下，云端可能已同步来部分分类，
    /// 逐项检查可避免重复插入，并能在同步完成后自动补齐缺失的内置分类。
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Category>())) ?? []
        var changed = false
        for (index, item) in builtins.enumerated() {
            let alreadyExists = existing.contains { $0.name == item.name && $0.type == item.type }
            if !alreadyExists {
                context.insert(Category(
                    name: item.name,
                    icon: item.icon,
                    type: item.type,
                    sortOrder: index,
                    isBuiltin: true
                ))
                changed = true
            }
        }
        if changed {
            try? context.save()
        }
    }
}

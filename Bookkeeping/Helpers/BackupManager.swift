import Foundation
import SwiftData
import CoreTransferable
import UniformTypeIdentifiers

/// JSON 备份 / 恢复（比 CSV 更完整：保留金额精度、分类关系与预算）
enum BackupManager {

    static let bookkeepingDirectoryName = "bookkeeping"
    static let bookkeepingFileName = "bookkeeping.json"

    // MARK: - 导出

    /// 导出全部数据为 JSON
    @MainActor
    static func exportJSON(from context: ModelContext) throws -> Data {
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        let categories = try context.fetch(FetchDescriptor<Category>())
        let budgets = try context.fetch(FetchDescriptor<Budget>())

        let payload = BackupPayload(
            version: 1,
            exportedAt: Date(),
            categories: categories.map {
                BackupCategory(
                    id: $0.id,
                    name: $0.name,
                    icon: $0.icon,
                    type: $0.type.rawValue,
                    sortOrder: $0.sortOrder,
                    isBuiltin: $0.isBuiltin,
                    isDeleted: $0.isDeleted
                )
            },
            transactions: transactions.map {
                BackupTransaction(
                    id: $0.id,
                    amount: "\($0.amount)",
                    date: $0.date,
                    note: $0.note,
                    type: $0.type.rawValue,
                    categoryId: $0.category?.id,
                    source: $0.source
                )
            },
            budgets: budgets.map {
                BackupBudget(id: $0.id, month: $0.month, amount: "\($0.amount)", isPermanent: $0.isPermanent)
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    /// 写入临时目录，返回文件 URL 供分享
    @MainActor
    static func writeTempJSON(from context: ModelContext) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("账本备份_\(DateFormatters.monthKey()).json")
        try exportJSON(from: context).write(to: url, options: .atomic)
        return url
    }

    /// 将当前完整账本镜像写入 App Documents/bookkeeping/bookkeeping.json。
    /// Documents 目录可通过“文件”App（开启文件共享后）访问和同步。
    @MainActor
    @discardableResult
    static func writeBookkeepingJSON(
        from context: ModelContext,
        documentsDirectory: URL? = nil
    ) throws -> URL {
        let documentsURL = documentsDirectory
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directoryURL = documentsURL.appendingPathComponent(bookkeepingDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent(bookkeepingFileName, isDirectory: false)
        try exportJSON(from: context).write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// 保存 SwiftData 后立即刷新本地账本 JSON 镜像。
    @MainActor
    static func save(context: ModelContext) throws {
        try context.save()
        try writeBookkeepingJSON(from: context)
    }

    // MARK: - 导入

    /// 导入备份：按 id / 月份幂等合并（已存在的记录跳过，不覆盖用户现有数据）
    @MainActor
    static func importJSON(data: Data, into context: ModelContext) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)
        guard payload.version == 1 else {
            throw BackupError.unsupportedVersion(payload.version)
        }

        var newCategories = 0
        var newTransactions = 0
        var newBudgets = 0

        // 1. 分类（先导入，流水需要引用）
        let allCategories = try context.fetch(FetchDescriptor<Category>())
        var idToCategory: [UUID: Category] = Dictionary(uniqueKeysWithValues: allCategories.map { ($0.id, $0) })

        for item in payload.categories {
            if let existingCategory = idToCategory[item.id] {
                if item.isDeleted == true { markDeleted(existingCategory) }
                continue
            }
            let type = TransactionType(rawValue: item.type) ?? .expense

            // 内置分类在不同设备上会有不同 UUID，按名称和类型复用本机种子分类。
            if item.isBuiltin,
               let existingBuiltin = allCategories.first(where: {
                   $0.isBuiltin && $0.name == item.name && $0.type == type
               }) {
                if item.isDeleted == true { markDeleted(existingBuiltin) }
                idToCategory[item.id] = existingBuiltin
                continue
            }

            let cat = Category(
                id: item.id,
                name: item.name,
                icon: item.icon,
                type: type,
                sortOrder: item.sortOrder,
                isBuiltin: item.isBuiltin,
                isDeleted: item.isDeleted ?? false
            )
            context.insert(cat)
            idToCategory[item.id] = cat
            newCategories += 1
        }

        // 2. 流水
        let existingTxIDs = Set(try context.fetch(FetchDescriptor<Transaction>()).map(\.id))
        for item in payload.transactions {
            guard !existingTxIDs.contains(item.id) else { continue }
            guard let amount = Decimal(string: item.amount, locale: Locale(identifier: "en_US_POSIX")) else { continue }
            let tx = Transaction(
                id: item.id,
                amount: amount,
                date: item.date,
                note: item.note,
                type: TransactionType(rawValue: item.type) ?? .expense,
                category: item.categoryId.flatMap { idToCategory[$0] }.flatMap { $0.isDeleted ? nil : $0 },
                source: item.source
            )
            context.insert(tx)
            newTransactions += 1
        }

        // 3. 预算（永久预算按标记幂等，旧版按月份兼容导入）
        let existingMonths = Set(try context.fetch(FetchDescriptor<Budget>()).map(\.month))
        var hasPermanentBudget = try context.fetch(FetchDescriptor<Budget>()).contains { $0.isPermanent }
        for item in payload.budgets {
            if item.isPermanent == true, hasPermanentBudget { continue }
            guard !existingMonths.contains(item.month) else { continue }
            guard let amount = Decimal(string: item.amount, locale: Locale(identifier: "en_US_POSIX")) else { continue }
            context.insert(Budget(id: item.id, month: item.month, amount: amount, isPermanent: item.isPermanent ?? false))
            if item.isPermanent == true { hasPermanentBudget = true }
            newBudgets += 1
        }

        try save(context: context)
        return ImportSummary(categories: newCategories, transactions: newTransactions, budgets: newBudgets)
    }

    struct ImportSummary {
        let categories: Int
        let transactions: Int
        let budgets: Int
        var total: Int { categories + transactions + budgets }
    }

    private static func markDeleted(_ category: Category) {
        guard !category.isDeleted else { return }
        for transaction in category.transactions {
            transaction.category = nil
        }
        category.isDeleted = true
    }

    enum BackupError: LocalizedError {
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version):
                return "不支持的备份文件版本（\(version)）"
            }
        }
    }
}

/// 用于分享导出的 JSON 备份文件
struct BackupFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .json) { file in
            SentTransferredFile(file.url)
        } importing: { _ in
            BackupFile(url: URL(fileURLWithPath: ""))
        }
    }
}

// MARK: - 备份数据模型

private struct BackupPayload: Codable {
    let version: Int
    let exportedAt: Date
    let categories: [BackupCategory]
    let transactions: [BackupTransaction]
    let budgets: [BackupBudget]
}

private struct BackupCategory: Codable {
    let id: UUID
    let name: String
    let icon: String
    let type: String
    let sortOrder: Int
    let isBuiltin: Bool
    let isDeleted: Bool?
}

private struct BackupTransaction: Codable {
    let id: UUID
    /// 金额以字符串保存，避免 JSON 数字精度损失
    let amount: String
    let date: Date
    let note: String
    let type: String
    let categoryId: UUID?
    let source: String
}

private struct BackupBudget: Codable {
    let id: UUID
    let month: String
    let amount: String
    let isPermanent: Bool?
}

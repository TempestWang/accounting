import XCTest
import SwiftData
@testable import Bookkeeping

final class BackupManagerTests: XCTestCase {

    @MainActor
    func testWriteBookkeepingJSONCreatesStableBookkeepingFile() throws {
        let schema = Schema([Transaction.self, Bookkeeping.Category.self, Budget.self, PendingTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let category = Bookkeeping.Category(name: "餐饮", icon: "fork.knife", type: .expense, sortOrder: 0)
        context.insert(category)
        context.insert(Transaction(amount: 12.5, note: "午餐", category: category))
        try context.save()

        let documentsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackupManagerTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: documentsDirectory) }

        let url = try BackupManager.writeBookkeepingJSON(
            from: context,
            documentsDirectory: documentsDirectory
        )

        XCTAssertEqual(url.lastPathComponent, BackupManager.bookkeepingFileName)
        XCTAssertEqual(url.deletingLastPathComponent().lastPathComponent, BackupManager.bookkeepingDirectoryName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let transactions = try XCTUnwrap(object["transactions"] as? [[String: Any]])
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions[0]["amount"] as? String, "12.5")
    }

    @MainActor
    func testImportReusesLocalBuiltinAndPreservesSameNamedCustomCategory() throws {
        let schema = Schema([Transaction.self, Bookkeeping.Category.self, Budget.self, PendingTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let localBuiltin = Bookkeeping.Category(
            name: "餐饮",
            icon: "fork.knife",
            type: .expense,
            sortOrder: 0,
            isBuiltin: true
        )
        context.insert(localBuiltin)

        let data = Data("""
        {
          "version": 1,
          "exportedAt": "2026-10-05T00:00:00Z",
          "categories": [
            {
              "id": "00000000-0000-0000-0000-000000000001",
              "name": "餐饮",
              "icon": "fork.knife",
              "type": "支出",
              "sortOrder": 0,
              "isBuiltin": true
            },
            {
              "id": "00000000-0000-0000-0000-000000000002",
              "name": "餐饮",
              "icon": "tag.fill",
              "type": "支出",
              "sortOrder": 1,
              "isBuiltin": false
            }
          ],
          "transactions": [
            {
              "id": "00000000-0000-0000-0000-000000000003",
              "amount": "12.50",
              "date": "2026-10-05T00:00:00Z",
              "note": "午餐",
              "type": "支出",
              "categoryId": "00000000-0000-0000-0000-000000000001",
              "source": "手动"
            }
          ],
          "budgets": []
        }
        """.utf8)

        let firstImport = try BackupManager.importJSON(data: data, into: context)
        let categories = try context.fetch(FetchDescriptor<Bookkeeping.Category>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())

        XCTAssertEqual(firstImport.categories, 1)
        XCTAssertEqual(categories.count, 2)
        XCTAssertEqual(transactions.count, 1)
        XCTAssertTrue(transactions[0].category === localBuiltin)

        let secondImport = try BackupManager.importJSON(data: data, into: context)

        XCTAssertEqual(secondImport.categories, 0)
        XCTAssertEqual(secondImport.transactions, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Bookkeeping.Category>()).count, 2)
    }

    @MainActor
    func testImportedBuiltinDeletionIsNotReseeded() throws {
        let schema = Schema([Transaction.self, Bookkeeping.Category.self, Budget.self, PendingTransaction.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let localBuiltin = Bookkeeping.Category(
            name: "餐饮",
            icon: "fork.knife",
            type: .expense,
            sortOrder: 0,
            isBuiltin: true
        )
        let transaction = Transaction(amount: 18, category: localBuiltin)
        context.insert(localBuiltin)
        context.insert(transaction)

        let data = Data("""
        {
          "version": 1,
          "exportedAt": "2026-10-05T00:00:00Z",
          "categories": [
            {
              "id": "00000000-0000-0000-0000-000000000011",
              "name": "餐饮",
              "icon": "fork.knife",
              "type": "支出",
              "sortOrder": 0,
              "isBuiltin": true,
              "isDeleted": true
            }
          ],
          "transactions": [],
          "budgets": []
        }
        """.utf8)

        let summary = try BackupManager.importJSON(data: data, into: context)
        let categoriesAfterImport = try context.fetch(FetchDescriptor<Bookkeeping.Category>())
        XCTAssertEqual(summary.categories, 0)
        XCTAssertEqual(categoriesAfterImport.map(\.isDeleted), [true], "Imported deletion state was not applied")
        PresetData.seedIfNeeded(context: context)

        let matchingCategories = try context.fetch(FetchDescriptor<Bookkeeping.Category>())
            .filter { $0.name == "餐饮" && $0.type == .expense }
        XCTAssertTrue(localBuiltin.isDeleted, "Local builtin deletion state was not updated")
        XCTAssertNil(transaction.category)
        XCTAssertEqual(matchingCategories.count, 1)
        XCTAssertTrue(matchingCategories[0].isDeleted)
    }
}

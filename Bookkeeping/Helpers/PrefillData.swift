import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// 记账表单的预填数据（相册识别 / 快捷指令解析后传入）
struct PrefillData {
    var amountText: String
    var note: String
    var categoryName: String?
    var date: Date?
    var type: TransactionType
    var source: String
}

/// 用于分享导出的 CSV 文件
struct CSVFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .commaSeparatedText) { csv in
            SentTransferredFile(csv.url)
        } importing: { _ in
            CSVFile(url: URL(fileURLWithPath: ""))
        }
    }
}

import Foundation

enum CSVExporter {
    /// 生成 CSV 字符串
    static func csvString(from transactions: [Transaction]) -> String {
        var lines = ["日期,类型,分类,金额,备注,来源"]
        for tx in transactions {
            let date = DateFormatters.fullDateTime(tx.date)
            let type = tx.type.rawValue
            let category = safeCell(tx.category?.name ?? "")
            let amount = DateFormatters.money(tx.amount)
            let note = safeCell(tx.note
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: ",", with: "，"))
            let source = safeCell(tx.source)
            lines.append([date, type, category, amount, note, source].joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    /// 防止 CSV 公式注入：以 = + - @ 开头的单元格加前缀单引号，
    /// 避免在 Excel / WPS 中打开时被当作公式执行
    private static func safeCell(_ value: String) -> String {
        let prefixChars: Set<Character> = ["=", "+", "-", "@"]
        if let first = value.first, prefixChars.contains(first) {
            return "'" + value
        }
        return value
    }

    /// 写入临时目录，返回文件 URL 供分享
    static func writeTempCSV(from transactions: [Transaction]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("账本流水_\(DateFormatters.monthKey()).csv")
        try csvString(from: transactions).write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

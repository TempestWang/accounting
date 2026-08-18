import Foundation
import SwiftUI

/// 收支类型
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense = "支出"
    case income = "收入"

    var id: String { rawValue }

    /// 展示用的图标
    var symbol: String {
        self == .expense ? "minus.circle.fill" : "plus.circle.fill"
    }

    /// 展示用颜色：支出红、收入绿
    var color: Color {
        self == .expense ? .red : .green
    }
}

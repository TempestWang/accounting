import SwiftUI
import SwiftData

@main
struct BookkeepingApp: App {
    /// 全局主题管理器（单例：驱动 8 套主题 + 外观模式）
    @StateObject private var theme = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(theme)
                .modelContainer(AppModel.container)
                // 全 App 用户可见内容固定中文：
                // - Locale 让 DatePicker / Swift Charts 坐标轴 / 系统组件自动使用中文（月份、星期、日期）；
                // - Calendar 固定公历，避免设备使用其他历法（佛历/和历等）时日期显示异常。
                // 仅作用于 SwiftUI 展示层；金额解析、JSON 备份等机器数据仍使用显式 en_US_POSIX，不受影响。
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .environment(\.calendar, Calendar(identifier: .gregorian))
                .task {
                    // 首次启动播种内置分类
                    let context = AppModel.container.mainContext
                    PresetData.seedIfNeeded(context: context)
                    // 即使没有新增数据，也确保本地账本文件已经存在。
                    try? BackupManager.writeBookkeepingJSON(from: context)
                }
        }
    }
}

/// 全局共享的 ModelContainer，App 界面与快捷指令意图共用同一存储
@MainActor
enum AppModel {
    static let container: ModelContainer = {
        let schema = Schema([Transaction.self, Category.self, Budget.self, PendingTransaction.self])
        do {
            let config = ModelConfiguration(schema: schema)
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let localConfig = ModelConfiguration(schema: schema)
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("无法创建数据存储: \(error)")
            }
        }
    }()
}

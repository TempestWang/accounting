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
            #if ENABLE_ICLOUD_SYNC
            // 启用 iCloud 云同步：需要付费开发者账号 + iCloud 能力 + 登录 iCloud，
            // 开启方法见 README「iCloud 云同步」章节。
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            #else
            // 默认：纯本地存储（免费开发者账号可直接真机运行，无需任何 iCloud 配置）
            let config = ModelConfiguration(schema: schema)
            #endif
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // 仅当启用 ENABLE_ICLOUD_SYNC 且 iCloud 不可用（未登录/未配置能力）时才会走到这里：
            // 自动降级为纯本地存储，保证 App 可用
            let localConfig = ModelConfiguration(schema: schema)
            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("无法创建数据存储: \(error)")
            }
        }
    }()
}

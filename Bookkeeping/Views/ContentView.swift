import SwiftUI
import SwiftData

/// 底部导航（仿鲨鱼记账）：首页 / 明细 / 统计 / 预算 / 我的
///
/// 同时承担「快捷指令截图识别 → 打开 App → 自动进入记一笔页面」的入口：
/// - 通过 @Query 响应式监听 PendingTransaction（快捷指令识别后的待确认账单），
///   冷启动 / 后台唤醒 / 前台运行三种场景下自动弹出现有「记一笔」页面并预填识别结果；
/// - 用户在记一笔页面核对、修改、保存（保存时才写入正式 Transaction）；
/// - 保存或取消后删除对应待确认账单，多笔时自动依次弹出下一笔。
struct ContentView: View {
    @Environment(\.modelContext) private var context

    /// 当前选中 Tab（由 RootView 持有并绑定，主题切换的全量重建后保持不变）
    @Binding var selection: Int

    @Query(sort: \PendingTransaction.createdAt, order: .reverse)
    private var pendingTransactions: [PendingTransaction]

    /// 当前正在处理（预填到记一笔页面）的待确认账单
    @State private var activePending: PendingTransaction?

    init(selection: Binding<Int>) {
        self._selection = selection
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("首页", systemImage: "house.fill") }
            .tag(0)

            NavigationStack {
                TransactionListView()
            }
            .tabItem { Label("明细", systemImage: "list.bullet.rectangle") }
            .tag(1)

            NavigationStack {
                StatisticsView()
            }
            .tabItem { Label("统计", systemImage: "chart.pie.fill") }
            .tag(2)

            NavigationStack {
                BudgetView()
            }
            .tabItem { Label("预算", systemImage: "target") }
            .tag(3)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("我的", systemImage: "person.fill") }
            .tag(4)
        }
        // UI优化：根据设计稿调整TabBar颜色为紫色
        .tint(DSColor.primary)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            activateNextPending()
        }
        .onChange(of: pendingTransactions.count) { _, _ in
            activateNextPending()
        }
        .sheet(item: $activePending) { pending in
            // 直接复用现有「记一笔」页面，预填识别结果；
            // 不弹出任何文件选择器，用户核对修改后保存（或取消）。
            TransactionFormView(prefill: TransactionImportService.prefillData(from: pending))
                .onDisappear {
                    // 保存 / 取消后：删除对应待确认账单，并继续处理下一笔
                    TransactionImportService.discard(pending, in: context)
                    activePending = nil
                    activateNextPending()
                }
        }
    }

    /// 有待确认账单且当前没有正在处理时，自动弹出下一笔
    private func activateNextPending() {
        guard activePending == nil, let next = pendingTransactions.first else { return }
        activePending = next
    }
}

// MARK: - 根视图（主题全局注入）

/// 根视图：主题系统与 TabView 的桥接，
/// - 通过 `@EnvironmentObject` 读取 ThemeManager，切换主题 / 外观后实时更新；
/// - `.id(theme.renderToken)`：主题切换时全量重建页面树，让所有直接引用
///   `DSColor.*` 的既有页面立即换肤；
/// - 主题设置 sheet 挂在最外层（不受重建影响），选主题时不被打断。
struct RootView: View {
    @EnvironmentObject private var theme: ThemeManager
    /// Tab 选择提升到根视图，重建后保持所在页面
    @State private var tabSelection = 0

    var body: some View {
        ZStack {
            ContentView(selection: $tabSelection)
                .id(theme.renderToken)
                .preferredColorScheme(theme.preferredColorScheme)
        }
        .sheet(isPresented: $theme.isThemeSettingsPresented) {
            ThemeSettingsView()
        }
    }
}

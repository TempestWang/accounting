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

    @Query(sort: \PendingTransaction.createdAt, order: .reverse)
    private var pendingTransactions: [PendingTransaction]

    /// 当前正在处理（预填到记一笔页面）的待确认账单
    @State private var activePending: PendingTransaction?

    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("首页", systemImage: "house.fill") }

            NavigationStack {
                TransactionListView()
            }
            .tabItem { Label("明细", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                StatisticsView()
            }
            .tabItem { Label("统计", systemImage: "chart.pie.fill") }

            NavigationStack {
                BudgetView()
            }
            .tabItem { Label("预算", systemImage: "target") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("我的", systemImage: "person.fill") }
        }
        .tint(AppTheme.primary)
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
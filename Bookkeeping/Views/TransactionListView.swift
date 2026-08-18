import SwiftUI
import SwiftData

/// 流水筛选
enum TxFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case expense = "支出"
    case income = "收入"
    var id: String { rawValue }
}

/// 明细页：全部/支出/收入筛选 + 按天分组流水
///
/// 数据源：@Query 直接监听 SwiftData 存储，新增 / 编辑 / 删除交易后
/// 列表自动刷新，不依赖手动刷新、onAppear 或 dismiss 时序。
/// 收入 / 支出筛选在内存中按类型过滤（与 BudgetService 一致：
/// SwiftData #Predicate 对 RawRepresentable 枚举成员的比较在部分系统版本
/// 会返回空结果，本项目实测即如此；日期谓词则不受影响）。
struct TransactionListView: View {
    @Environment(\.modelContext) private var context

    /// 全部流水（按日期倒序；@Query 随数据变化自动更新）
    @Query(sort: \Transaction.date, order: .reverse)
    private var allTransactions: [Transaction]

    @State private var filter: TxFilter = .all
    @State private var showForm = false
    @State private var showRecognition = false
    @State private var editingTransaction: Transaction?
    @State private var showError = false
    @State private var errorText = ""

    /// 当前筛选下的流水
    private var transactions: [Transaction] {
        switch filter {
        case .all:
            return allTransactions
        case .expense:
            return allTransactions.filter { $0.type == .expense }
        case .income:
            return allTransactions.filter { $0.type == .income }
        }
    }

    var body: some View {
        List {
            Section {
                Picker("筛选", selection: $filter) {
                    ForEach(TxFilter.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
            }

            ForEach(groupedByDay, id: \.0) { day, items in
                Section {
                    ForEach(items) { tx in
                        TransactionRow(transaction: tx)
                            .contentShape(Rectangle())
                            .onTapGesture { editingTransaction = tx }
                    }
                    .onDelete { offsets in
                        delete(items: items, at: offsets)
                    }
                } header: {
                    HStack {
                        Text(DateFormatters.dayHeader(day))
                        Spacer()
                        Text(dayTotal(items))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .background(AppTheme.background)
        .navigationTitle("明细")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showRecognition = true
                } label: {
                    Image(systemName: "text.viewfinder")
                }
                .accessibilityLabel("从截图识别记账")

                Button {
                    showForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("记一笔")
            }
        }
        .sheet(isPresented: $showForm) {
            TransactionFormView()
        }
        .sheet(item: $editingTransaction) { tx in
            TransactionFormView(editing: tx)
        }
        .sheet(isPresented: $showRecognition) {
            ImageRecognitionView()
        }
        .alert("提示", isPresented: $showError) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorText)
        }
        .overlay {
            if transactions.isEmpty {
                ContentUnavailableView(
                    "暂无账目",
                    systemImage: "tray",
                    description: Text("点击右上角 + 记一笔，或从付款截图自动识别。")
                )
            }
        }
    }

    // MARK: - 分组与统计

    private var groupedByDay: [(Date, [Transaction])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: transactions) { cal.startOfDay(for: $0.date) }
        return dict.keys.sorted(by: >).map { day in
            (day, dict[day]!.sorted { $0.date > $1.date })
        }
    }

    private func dayTotal(_ items: [Transaction]) -> String {
        let exp = items.filter { $0.type == .expense }
            .reduce(Decimal.zero) { $0 + $1.amount }
        let inc = items.filter { $0.type == .income }
            .reduce(Decimal.zero) { $0 + $1.amount }
        var parts: [String] = []
        if exp > 0 { parts.append("支出 \(DateFormatters.money(exp))") }
        if inc > 0 { parts.append("收入 \(DateFormatters.money(inc))") }
        return parts.joined(separator: " · ")
    }

    // MARK: - 删除（@Query 自动刷新，无需手动重新加载）

    private func delete(items: [Transaction], at offsets: IndexSet) {
        for index in offsets {
            context.delete(items[index])
        }
        do {
            try context.save()
        } catch {
            errorText = "删除失败，请重试。"
            showError = true
        }
    }
}
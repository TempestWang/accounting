import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置页：分类管理、预算、导出 CSV、JSON 备份、自动化记账教程
struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @Query private var transactions: [Transaction]

    @State private var showCategories = false
    @State private var showBudget = false
    @State private var csvFile: CSVFile?
    @State private var backupFile: BackupFile?
    @State private var showImporter = false
    @State private var showImportResult = false
    @State private var importMessage = ""

    var body: some View {
        List {
            Section("记账") {
                Button {
                    showCategories = true
                } label: {
                    Label("分类管理", systemImage: "square.grid.2x2")
                }
                Button {
                    showBudget = true
                } label: {
                    Label("本月预算", systemImage: "target")
                }
            }

            Section("iCloud 同步") {
                HStack {
                    Label("iCloud 同步", systemImage: "icloud")
                    Spacer()
                    Text(isICloudAvailable ? "已开启" : "未开启")
                        .foregroundStyle(isICloudAvailable ? AppTheme.income : .secondary)
                }
                Text(isICloudAvailable
                     ? "账目会自动同步到你的 iCloud 账户，换机登录同一 Apple ID 即可恢复。"
                     : "当前未启用（云同步需要付费开发者账号）。未启用时数据仅保存在本机，可用 JSON 备份导出/导入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("数据") {
                if let csvFile {
                    ShareLink(item: csvFile, preview: SharePreview("账本流水 CSV")) {
                        Label("导出 CSV", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Label("导出失败", systemImage: "exclamationmark.triangle")
                }

                if let backupFile {
                    ShareLink(item: backupFile, preview: SharePreview("账本备份")) {
                        Label("导出备份（JSON）", systemImage: "archivebox")
                    }
                }

                Button {
                    showImporter = true
                } label: {
                    Label("导入备份（JSON）", systemImage: "tray.and.arrow.down")
                }
            }

            Section("自动化记账") {
                NavigationLink {
                    ShortcutGuideView()
                } label: {
                    Label("快捷指令搭建教程", systemImage: "bolt.fill")
                }
            }

            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
                Text("数据会自动同步到 iCloud（需登录 iCloud），建议定期导出 JSON 备份，双保险更安心。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .background(AppTheme.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("我的")
        .sheet(isPresented: $showCategories) {
            CategoryManageView()
        }
        .sheet(isPresented: $showBudget) {
            BudgetEditView()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert("导入备份", isPresented: $showImportResult) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importMessage)
        }
        .task {
            generateExportFiles()
        }
    }

    // MARK: - iCloud 状态

    /// iCloud 是否可用（是否登录由系统管理；未启用 iCloud 能力时恒为 false）
    private var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: - 导出文件（进入页面时生成一次，避免每次刷新重写）

    private func generateExportFiles() {
        if csvFile == nil, let url = try? CSVExporter.writeTempCSV(from: transactions) {
            csvFile = CSVFile(url: url)
        }
        if backupFile == nil, let url = try? BackupManager.writeTempJSON(from: context) {
            backupFile = BackupFile(url: url)
        }
    }

    // MARK: - 导入备份

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: url) else {
            importMessage = "无法读取备份文件，请确认选择了正确的 JSON 备份。"
            showImportResult = true
            return
        }
        do {
            let summary = try BackupManager.importJSON(data: data, into: context)
            importMessage = "导入完成：分类 \(summary.categories) 个、流水 \(summary.transactions) 笔、预算 \(summary.budgets) 个；已存在的记录已自动跳过。"
            // 导入后重新生成导出文件，保证内容最新
            csvFile = nil
            backupFile = nil
            generateExportFiles()
        } catch {
            // 不直接透出系统错误原文（可能为英文），统一中文提示
            importMessage = "导入失败，请确认选择了正确的 JSON 备份文件。"
        }
        showImportResult = true
    }
}

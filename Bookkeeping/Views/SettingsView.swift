import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 设置页：分类管理、预算、导出 CSV、JSON 备份、自动化记账教程
/// UI优化：参考设计稿添加紫色渐变头部
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
        ScrollView {
            VStack(spacing: 0) {
                // UI优化：参考设计稿添加紫色渐变头部
                profileHeader
                    .padding(.bottom, 16)

                VStack(spacing: AppSpacing.l) {
                    themeSection
                    settingsSection
                    icloudSection
                    dataSection
                    automationSection
                    aboutSection
                }
                .padding(.horizontal, AppSpacing.l)
            }
        }
        // UI优化：根据设计稿调整背景色
        .background(DSColor.background)
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - 个人资料头部（UI优化：参考设计稿紫色渐变）

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DSColor.primary, DSColor.purpleGradientEnd],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                Image(systemName: "person.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(DSColor.buttonText)
            }

            Text("小记账")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            Text("记账 · 更轻松")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            LinearGradient(
                colors: [DSColor.primary.opacity(0.12), DSColor.primary.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - 主题与外观

    private var themeSection: some View {
        VStack(spacing: 0) {
            Button {
                ThemeManager.shared.presentThemeSettings()
            } label: {
                settingsRow(
                    icon: "paintpalette.fill",
                    iconColor: DSColor.primary,
                    title: "主题设置",
                    trailing: {
                        Text(ThemeManager.shared.theme.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.theme")
            settingsDivider
            Button {
                ThemeManager.shared.presentThemeSettings()
            } label: {
                settingsRow(
                    icon: ThemeManager.shared.appearanceMode.symbolName,
                    iconColor: DSColor.primary,
                    title: "外观",
                    trailing: {
                        Text(ThemeManager.shared.appearanceMode.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                )
            }
            .buttonStyle(.plain)
        }
        .dsCard(padding: 0)
    }

    // MARK: - 记账设置

    private var settingsSection: some View {
        VStack(spacing: 0) {
            Button {
                showCategories = true
            } label: {
                settingsRow(
                    icon: "square.grid.2x2",
                    iconColor: DSColor.primary,
                    title: "分类管理"
                )
            }
            .buttonStyle(.plain)
            settingsDivider
            Button {
                showBudget = true
            } label: {
                settingsRow(
                    icon: "target",
                    iconColor: DSColor.healthy,
                    title: "本月预算"
                )
            }
            .buttonStyle(.plain)
        }
        .dsCard(padding: 0)
    }

    // MARK: - iCloud 同步

    private var icloudSection: some View {
        VStack(spacing: 0) {
            settingsRow(
                icon: "icloud",
                iconColor: DSColor.primary,
                title: "iCloud 同步",
                trailing: {
                    Text(isICloudAvailable ? "已开启" : "未开启")
                        .font(.caption)
                        .foregroundStyle(isICloudAvailable ? DSColor.income : .secondary)
                }
            )
            settingsDivider
            VStack(alignment: .leading, spacing: 4) {
                Text(isICloudAvailable
                     ? "账目会自动同步到你的 iCloud 账户，换机登录同一 Apple ID 即可恢复。"
                     : "当前未启用（云同步需要付费开发者账号）。未启用时数据仅保存在本机，可用 JSON 备份导出/导入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.m)
        }
        .dsCard(padding: 0)
    }

    // MARK: - 数据

    private var dataSection: some View {
        VStack(spacing: 0) {
            if let csvFile {
                ShareLink(item: csvFile, preview: SharePreview("账本流水 CSV")) {
                    settingsRow(
                        icon: "square.and.arrow.up",
                        iconColor: DSColor.primary,
                        title: "导出 CSV"
                    )
                }
            } else {
                settingsRow(
                    icon: "exclamationmark.triangle",
                    iconColor: DSColor.warning,
                    title: "导出失败"
                )
            }

            settingsDivider

            if let backupFile {
                ShareLink(item: backupFile, preview: SharePreview("账本备份")) {
                    settingsRow(
                        icon: "archivebox",
                        iconColor: DSColor.primary,
                        title: "导出备份（JSON）"
                    )
                }
            }

            settingsDivider

            Button {
                showImporter = true
            } label: {
                settingsRow(
                    icon: "tray.and.arrow.down",
                    iconColor: DSColor.healthy,
                    title: "导入备份（JSON）"
                )
            }
            .buttonStyle(.plain)
        }
        .dsCard(padding: 0)
    }

    // MARK: - 自动化记账

    private var automationSection: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ShortcutGuideView()
            } label: {
                settingsRow(
                    icon: "bolt.fill",
                    iconColor: DSColor.warning,
                    title: "快捷指令搭建教程"
                )
            }
        }
        .dsCard(padding: 0)
    }

    // MARK: - 关于

    private var aboutSection: some View {
        VStack(spacing: 0) {
            settingsRow(
                icon: "info.circle",
                iconColor: .secondary,
                title: "版本",
                trailing: {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            )
            settingsDivider
            VStack(alignment: .leading, spacing: 4) {
                Text("数据会自动同步到 iCloud（需登录 iCloud），建议定期导出 JSON 备份，双保险更安心。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.m)
        }
        .dsCard(padding: 0)
    }

    // MARK: - 通用设置行

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: String,
        trailing: @escaping () -> some View = { EmptyView() }
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(iconColor.opacity(0.12)))

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            trailing()
                .padding(.trailing, 24)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(DSColor.hairline)
            .frame(height: 0.5)
            .padding(.leading, 64)
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

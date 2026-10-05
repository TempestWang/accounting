import SwiftUI
import SwiftData

/// 分类管理：内置分类可删除，自定义分类可增删改
/// UI优化：根据设计稿调整列表样式
struct CategoryManageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode

    @Query(sort: \Category.sortOrder)
    private var categories: [Category]

    @State private var showAdd = false
    @State private var editing: Category?

    /// 待删除确认的分类及其名下流水数
    @State private var confirmDelete: Category?
    @State private var deleteCount = 0
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("支出分类") {
                    categoryList(type: .expense)
                }
                Section("收入分类") {
                    categoryList(type: .income)
                }
            }
            .navigationTitle("分类管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(DSColor.primary)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加分类")
                }
                ToolbarItem(placement: .automatic) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showAdd) {
                CategoryEditView()
            }
            .sheet(item: $editing) { cat in
                CategoryEditView(editing: cat)
            }
            .alert("删除分类", isPresented: deleteConfirmBinding, presenting: confirmDelete) { _ in
                Button("删除", role: .destructive) { performDelete() }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text(deleteCount > 0
                     ? "该分类下有 \(deleteCount) 笔流水，删除后它们将变为「未分类」。"
                     : "确定删除该分类吗？")
            }
        }
        .alert("提示", isPresented: errorBinding) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func categoryList(type: TransactionType) -> some View {
        let items = categories.filter { $0.type == type && !$0.isDeleted }
        return ForEach(items) { cat in
            row(cat)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard editMode?.wrappedValue != .active else { return }
                    editing = cat
                }
        }
        .onDelete { offsets in
            requestDelete(items: items, at: offsets)
        }
        .onMove { offsets, destination in
            reorder(items: items, from: offsets, to: destination)
        }
    }

    private func reorder(items: [Category], from offsets: IndexSet, to destination: Int) {
        var reordered = items
        reordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortOrder = index
        }
        do {
            try BackupManager.save(context: context)
        } catch {
            errorMessage = "排序保存失败，请重试。"
        }
    }

    private func row(_ cat: Category) -> some View {
        HStack(spacing: 12) {
            // UI优化：参考设计稿使用圆角方形图标背景
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ColorPalette.color(for: cat.name).opacity(0.15))
                    .frame(width: 32, height: 32)
                DSCategoryGlyph(
                    icon: cat.icon,
                    color: ColorPalette.color(for: cat.name),
                    size: 16
                )
            }
            Text(cat.name)
            if cat.isBuiltin {
                Text("内置")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func requestDelete(items: [Category], at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let cat = items[index]
        // 统计该分类下的流水数，用于删除确认提示
        // Predicate 宏要求等号两侧类型完全一致：$0.category?.id 是 UUID?，
        // 因此目标 id 也必须以 UUID? 捕获（而非非可选 UUID）
        let targetID: UUID? = cat.id
        let count = (try? context.fetchCount(
            FetchDescriptor<Transaction>(predicate: #Predicate<Transaction> { $0.category?.id == targetID })
        )) ?? 0
        deleteCount = count
        confirmDelete = cat
    }

    private func performDelete() {
        guard let cat = confirmDelete else { return }
        confirmDelete = nil
        if cat.isBuiltin {
            for transaction in cat.transactions {
                transaction.category = nil
            }
            cat.isDeleted = true
        } else {
            context.delete(cat)
        }
        do {
            try BackupManager.save(context: context)
        } catch {
            errorMessage = "删除失败，请重试。"
        }
    }

    private var deleteConfirmBinding: Binding<Bool> {
        Binding(
            get: { confirmDelete != nil },
            set: { if !$0 { confirmDelete = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

/// 添加 / 编辑分类
struct CategoryEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var editing: Category?

    @State private var name: String = ""
    @State private var icon: String = "tag.fill"
    @State private var emojiIcon: String = ""
    @State private var type: TransactionType = .expense
    @State private var showError = false
    @State private var errorText = ""

    private static let iconChoices: [String] = [
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        "car.fill", "bus.fill", "train.side.front.car", "airplane", "bicycle",
        "bag.fill", "cart.fill", "gift.fill", "tag.fill",
        "house.fill", "lightbulb.fill", "drop.fill", "bolt.fill",
        "gamecontroller.fill", "film.fill", "music.note", "ticket.fill",
        "cross.case.fill", "stethoscope", "pills.fill", "heart.fill",
        "book.fill", "graduationcap.fill", "pencil",
        "banknote.fill", "trophy.fill", "chart.line.uptrend.xyaxis", "briefcase.fill",
        "ellipsis.circle.fill", "square.grid.2x2", "dollarsign.circle.fill", "creditcard.fill",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("分类名称", text: $name)
                    // 新建时始终可选类型；编辑时仅在分类下没有流水时允许修改类型
                    if editing == nil || (editing?.transactions.isEmpty ?? true) {
                        Picker("类型", selection: $type) {
                            Text("支出").tag(TransactionType.expense)
                            Text("收入").tag(TransactionType.income)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("图标") {
                    // iPad 等宽屏下增加列数
                    let columns = Array(repeating: GridItem(.flexible()), count: horizontalSizeClass == .regular ? 10 : 6)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Self.iconChoices, id: \.self) { symbol in
                            Button {
                                icon = symbol
                                emojiIcon = ""
                            } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 20))
                                    .foregroundStyle(icon == symbol ? DSColor.primary : .secondary)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        // UI优化：参考设计稿使用圆角方形
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(
                                                icon == symbol ? DSColor.primary.opacity(0.16) : Color.clear
                                            )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(
                                                icon == symbol ? DSColor.primary.opacity(0.75) : .clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            }
                            .buttonStyle(DSScaleButtonStyle())
                            .animation(AppAnimation.smooth, value: icon)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("自定义表情") {
                    TextField("输入一个表情", text: $emojiIcon)
                        .onChange(of: emojiIcon) { _, value in
                            applyEmojiIcon(value)
                        }

                    if !emojiIcon.isEmpty {
                        HStack {
                            DSCategoryGlyph(
                                icon: emojiIcon,
                                color: ColorPalette.color(for: name),
                                size: 28
                            )
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle(editing == nil ? "添加分类" : "编辑分类")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .foregroundStyle(DSColor.primary)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let editing {
                    name = editing.name
                    icon = editing.icon
                    emojiIcon = editing.icon.containsEmojiGlyph ? editing.icon : ""
                    type = editing.type
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorText)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorText = "分类名称不能为空。"
            showError = true
            return
        }
        do {
            if let editing {
                editing.name = trimmed
                editing.icon = icon
                editing.type = type
            } else {
                let maxOrder = (try? context.fetch(FetchDescriptor<Category>()))
                    .map { $0.map(\.sortOrder).max() ?? 0 } ?? 0
                context.insert(Category(name: trimmed, icon: icon, type: type, sortOrder: maxOrder + 1))
            }
            try BackupManager.save(context: context)
            dismiss()
        } catch {
            errorText = "保存失败，请重试。"
            showError = true
        }
    }

    private func applyEmojiIcon(_ value: String) {
        guard !value.isEmpty else { return }
        let candidate = String(value.prefix(1))
        guard candidate.containsEmojiGlyph else {
            emojiIcon = ""
            return
        }
        if candidate != value {
            emojiIcon = candidate
        }
        icon = candidate
    }
}

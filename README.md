# 账本 · iOS 记账应用

一个基于 SwiftUI + SwiftData 的本地记账 App，核心亮点是**自动化记账**：付款页截屏后敲一下 iPhone 背面，自动 OCR 识别金额、商户、日期并记入账本。

## 功能

- **界面风格**：蓝主题、白色圆角卡片、首页总览大卡片、底部四标签（首页 / 明细 / 统计 / 我的）
- **首页总览**：本月支出大数字 + 收入/结余 + 预算进度条，彩色分类快捷记账，最近流水，悬浮「记一笔」按钮
- **明细列表**：全部 / 支出 / 收入 筛选，按天分组、每日小计、滑动删除、点击编辑
- **统计报表**：月度 / 年度切换、支出 / 收入切换、分类排行（百分比 + 进度条 + 金额）、支出占比环图、每日支出柱状图、近 6 月收支趋势、预算进度
- **分类管理**：内置分类 + 自定义分类（图标 / 名称 / 类型）
- **预算**：设置每月支出预算，进度条展示，超支红色提醒
- **CSV 导出**：一键分享全部流水
- **JSON 备份/恢复**：完整备份分类 / 流水 / 预算（保留金额精度），可导入恢复，防止换机或误删丢失数据
- **iCloud 云同步**：登录 iCloud 后账目自动跨设备同步（默认关闭；需要付费开发者账号，免费账号不可用）
- **自动化记账**（核心）：
  1. **双敲背面全自动**：敲两下截屏 → 敲三下快捷指令自动记账
  2. **截图分享直达**：截屏后从分享面板选「账本记账」
  3. **相册识别**：App 内选付款截图识别记账
  - Vision 离线 OCR（中文）+ 启发式解析金额 / 商户 / 日期 / 分类

## 目录结构

```
accounting/
├── README.md
├── project.yml                    # XcodeGen 备用工程配置
├── Bookkeeping.xcodeproj/         # 手写 Xcode 工程（Xcode 16 文件夹同步格式）
└── Bookkeeping/                   # 全部源码（文件夹自动纳入编译）
    ├── BookkeepingApp.swift       # 入口 + 数据容器
    ├── Models/                    # Transaction / Category / Budget / TransactionType
    ├── Intents/                   # 快捷指令 App Intent + Siri 短语
    ├── Services/                  # OCRService（Vision）/ PaymentParser（解析）
    ├── Views/                     # 明细 / 表单 / 统计 / 设置 / 分类 / 识别
    ├── Helpers/                   # 默认分类 / 日期格式化 / CSV / 配色
    └── Assets.xcassets/           # 图标与主题色
```

## 在 Mac 上运行

**所需工具**：

| 工具 | 要求 | 说明 |
|---|---|---|
| Mac | macOS 14.5+（建议 15 Sequoia） | Apple Silicon / Intel 均可 |
| Xcode | **16.0+**（App Store 免费下载，约 10GB） | 工程用了 Xcode 16 文件夹同步格式；Xcode 15 需用 XcodeGen 兜底 |
| Apple ID | 免费即可 | 模拟器运行不需要；真机运行需要 |
| XcodeGen（可选） | `brew install xcodegen` | 仅当工程打不开时的兜底 |
| 依赖 | 无 | 纯系统框架，无 CocoaPods / SPM / 第三方库 |

**系统要求**：macOS 14.5+、Xcode 16+（本项目用 SwiftData，最低 iOS 17；免费账号真机不需要付费）。

### 1. 拷贝到 Mac

把整个 `accounting` 文件夹复制到 Mac，任选一种方式：

- **U 盘**：整个文件夹直接拷贝（最可靠）；
- **微信/网盘**：建议先打包成 zip 再传，传到 Mac 后解压；
- **AirDrop**：两台 Mac 之间最快。

> 注意：拷贝后确认目录结构完整——`accounting/Bookkeeping.xcodeproj` 与 `accounting/Bookkeeping/`（源码）同级。

### 2. 打开工程

两种方式任选：

**方式 A（推荐，直接打开）**：双击 `Bookkeeping.xcodeproj`。需要 **Xcode 16+**（因为工程用了 Xcode 16 的文件夹同步格式）。

**方式 B（XcodeGen 兜底）**：如果工程打不开或你的 Xcode 是 15，用 XcodeGen 重新生成。安装方式二选一：

- 有 Homebrew：`brew install xcodegen`
- 没有 Homebrew：去 [XcodeGen GitHub Releases](https://github.com/yonaskolb/XcodeGen/releases/latest) 下载 `xcodegen.zip`，解压后在解压目录里用 `./xcodegen` 运行（或 `sudo mv xcodegen /usr/local/bin/` 后全局使用）

然后执行：
```bash
cd accounting
xcodegen
```
会重新生成 `Bookkeeping.xcodeproj`，然后打开即可。

### 3. 设置签名

1. 在 Xcode 左侧选中工程 → `Bookkeeping` target → `Signing & Capabilities`
2. 勾选 **Automatically manage signing**
3. **Team** 选择你的 Apple ID（第一次请先登录：Xcode → Settings → Accounts → 添加 Apple ID）
4. 把 **Bundle Identifier** 从 `com.example.Bookkeeping` 改成你自己的，如 `com.你的昵称.zhangben`（免费账号要求每个设备上的 Bundle ID 唯一）
5. 工程**默认未启用** iCloud 能力，免费账号无需任何额外设置，直接 ⌘R 即可真机运行

### 4. 运行

- **模拟器**：顶栏选一个 iPhone 模拟器，按 ⌘R 直接运行，无需任何账号。
- **真机（免费账号，无需付费）**：
  1. iPhone 用数据线连 Mac，解锁并点「信任此电脑」
  2. Xcode 顶栏选择你的 iPhone
  3. 按 ⌘R。首次会提示在「设置 → 通用 → VPN与设备管理」里信任你的开发者证书
  4. ⚠️ 免费签名有效期 **7 天**，过期后在手机上打不开 App，需重新连接 Mac 运行一次

### 5. 打包成 IPA（上架 / 分发需要付费）

免费账号**无法**导出可长期使用的 IPA。需要：
- 付费 Apple Developer 账号（¥688/年 / $99/年）
- Xcode → Product → Archive → Distribute App（可导出 Ad Hoc / TestFlight / App Store）

### 6. 常见问题排查

| 现象 | 处理 |
|---|---|
| 双击工程打不开 / 提示项目损坏 | 用 XcodeGen 重新生成（方式 B），或确认文件传输完整 |
| 真机报 `Signing for 'Bookkeeping' requires a development team` | Xcode → Signing & Capabilities → Team 选你的 Apple ID |
| 真机报 `Failed to register bundle identifier` | Bundle ID 与已有 App 冲突，换一个（如 `com.你的昵称.zhangben`） |
| 手机提示「未受信任的开发者」/ App 闪退打不开 | 设置 → 通用 → VPN与设备管理 → 信任开发者证书 |
| 手机连不上 Xcode | 解锁 iPhone、点「信任此电脑」、换一根数据线，或重启 Xcode |
| 模拟器/真机系统版本过低 | 设备 iOS 需 ≥ 17.0 |
| 更新代码后启动闪退 | 开发期 Schema 变更导致迁移失败：删除 App 重装（先「导出备份（JSON）」） |
| 首次启动后设置页显示「iCloud 同步：未开启」 | 正常现象，免费账号不支持云同步，数据仅在本机 |

## 快捷指令搭建教程（自动化记账）

> 前提：App 已装到你的 iPhone。首次运行 App 一次，让系统注册快捷指令动作。

### ① 设置「敲两下背面 = 截屏」

设置 → 辅助功能 → 触控 → **轻点背面** → **轻点两下** → 选择「**截屏**」

### ② 新建快捷指令「账本记账」

1. 打开「快捷指令」App → 右上角 `+` 新建
2. 添加动作：
   - **获取最近的照片**（`App` 分类下，选「最近的照片」）
   - **从图像中提取文本**（`图像` 分类；「图像」参数选上一步的「最近的照片」）
   - **运行 账本 的「识别屏幕并记账」**（`App` 分类；该动作参数「识别文本」选上一步的「提取的文本」）
3. 快捷指令顶部可以重命名「账本记账」

### ③ 设置「敲三下背面」触发

设置 → 辅助功能 → 触控 → **轻点背面** → **轻点三下** → 「快捷指令」→ 选「**账本记账**」

### ④ 使用

付款页面：
1. **敲两下背面**（截屏，自动存相册）
2. **敲三下背面**（运行快捷指令）
3. 屏幕上会出现「已自动记账 ¥12.50 · 星巴克（餐饮）」结果卡片

到「账本」App 的明细里核对，识别错的左滑删除即可。

### ⑤ 分享面板直达（可选）

在快捷指令 App 里打开「账本记账」→ 右上角 `...` → 打开「**在共享表单中显示**」。
之后付款截屏 → 点左下角截图缩略图 → 右上角分享 → 选「账本记账」，同样自动记账。

### ⑥ Siri 语音记账（可选）

快捷指令详情里点「添加到 Siri」，录一句「**用账本识别记账**」，之后对 Siri 说这句话即可触发（但前提是当前已有一张最新的付款截图）。

## 关于「自动识别当前屏幕」

你可能期望「敲一下就自动读取当前屏幕直接记账」。**iOS 出于隐私限制，不允许任何 App 或快捷指令直接截取其他 App 的屏幕内容**，快捷指令里也没有「截取当前屏幕」的动作（Android 可以，iOS 不行）。因此本方案用「敲两下截屏 + 敲三下记账」的两步方案，已经是 iOS 上最接近全自动的做法。如果你发现某个快捷指令版本里存在「截屏」动作，可以在快捷指令里把它放在「获取最近的照片」之前，就能一步完成。

## iCloud 云同步（可选，默认关闭）

App 内置了 SwiftData 的 CloudKit 同步代码，但**默认关闭**：免费开发者账号不支持 iCloud 能力，开启会导致真机签名失败，因此本项目开箱即用时不带 iCloud 能力。

**当前状态（免费账号）**：纯本地存储，真机 / 模拟器直接运行，设置页显示「iCloud 同步：未开启」。数据只保存在本机，用「导出备份（JSON）/ 导入备份（JSON）」即可完成迁移。

**将来购买付费开发者账号后，三步开启**：

1. 把 iCloud 能力挂回工程：在 `Signing & Capabilities` 添加 iCloud → 勾选 CloudKit（或在 pbxproj / project.yml 的 target 配置中恢复 `CODE_SIGN_ENTITLEMENTS = Bookkeeping/Bookkeeping.entitlements`，文件已就绪）；
2. `Build Settings` → `SWIFT_ACTIVE_COMPILATION_CONDITIONS` 增加 `ENABLE_ICLOUD_SYNC`；
3. iPhone 登录 iCloud 后重新运行，现有数据会自动上传并跨设备同步。

**注意事项**：

1. **schema 上线即定型**：启用同步后首次运行会在 CloudKit 开发环境自动建表；若将来上架，需在 [CloudKit Dashboard](https://icloud.developer.apple.com) 把 schema **Deploy 到 Production**。模型一旦同步上线，**新增字段可自动迁移，重命名/删除字段会导致同步失败**（个人使用影响不大，改完重装即可）。
2. **多设备播种**：两台设备同时全新安装且离线使用时，内置分类联网合并后可能出现重复（已按名称去重播种，仍存在极端并发窗口），可在「分类管理」手动删除。
3. **数据安全**：iCloud 数据由苹果托管加密传输，App 本身依然没有任何自有网络请求；未开启同步时数据只在本机沙盒。
4. **删除同步**：在任一设备删除流水/分类后，其他设备同步后也会删除（CloudKit 墓碑机制）。
5. **模型已 CloudKit 兼容**：数据模型（属性全部可选/带默认值、无 unique 约束）按 CloudKit 要求设计，将来启用同步时无需再改模型。

## 常见问题

**Q：解析的分类不对 / 商户识别不准？**
A：分类关键词在 `Bookkeeping/Services/PaymentParser.swift` 的 `categoryKeywords` 里，可自行增删；解析是启发式的，误差可通过明细里左滑删除或点击编辑修正。

**Q：数据存在哪里？**
A：全部存在本机 App 沙盒（SwiftData），不上传任何自有服务器。云同步默认关闭（免费账号不可用）；若将来启用，数据会通过苹果 CloudKit 自动同步到同一 Apple ID 的其他设备。建议定期在设置里「导出备份（JSON）」；换机或重装后通过「导入备份（JSON）」恢复。

**Q：更新版本后启动闪退？**
A：开发期数据模型（Schema）变更偶尔会导致 SwiftData 迁移失败。个人使用建议：每次更新前先在设置里「导出备份（JSON）」；若更新后闪退，删除 App 重装，再「导入备份」恢复即可。

**Q：能上架 App Store 吗？**
A：可以，但需要付费开发者账号并按 App Store 审核规范补充隐私说明等材料。

## 技术栈

SwiftUI · SwiftData（iOS 17+）· Swift Charts · Vision OCR · App Intents · CloudKit 云同步（可选，默认关闭）

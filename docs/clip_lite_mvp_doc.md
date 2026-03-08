# macOS 剪贴板工具 MVP 实现文档（代码对齐版 V1.2）

## 1. 文档信息

**项目名称**
ClipLite

**文档版本**
V1.2（按仓库当前实现更新）

**实现快照日期**
2026-03-02

**目标**
让文档与仓库当前代码行为保持一致，作为后续迭代与发布基线。

---

## 2. 当前 MVP 范围

### 2.1 已实现能力
1. 菜单栏常驻（Agent）应用形态。
2. 全局热键唤起历史面板（默认 `Command + ;`）。
3. 文本与图片历史记录。
4. 键盘选择与回车直接粘贴。
5. 自动粘贴失败时降级为“仅复制”。
6. 设置项：开机自启、主题、热键预设、存储策略、高级过滤。
7. SQLite + 本地文件存储。
8. 启动清理与节流清理。

### 2.2 当前不在实现范围（仍未落地）
1. iCloud/多端同步。
2. OCR。
3. 收藏夹、标签、分组体系。
4. 任意快捷键录制（当前仅预设）。
5. 正式签名、公证、自动升级发布链路。

---

## 3. 运行形态与系统配置

### 3.1 应用形态
1. `Info.plist` 中 `LSUIElement = YES`。
2. 启动时 `NSApplication` 使用 `.accessory`。
3. 无 Dock 图标，通过菜单栏图标交互。

### 3.2 最低系统版本
1. `macOS 13.0+`（`Package.swift` 与 `Info.plist` 一致）。

---

## 4. 技术栈（实际实现）

1. 语言：Swift 6.2。
2. UI：SwiftUI + AppKit。
3. 存储：SQLite3 + 本地文件系统。
4. 图片处理：AppKit（`NSImage` / `NSBitmapImageRep`）。
5. 全局热键：Carbon `RegisterEventHotKey`（非第三方库）。
6. 开机自启：`SMAppService.mainApp`。
7. 系统剪贴板：`NSPasteboard`。
8. 自动粘贴注入：`CGEvent`（依赖 Accessibility 权限）。

---

## 5. 功能规格（按代码行为）

## 5.1 菜单栏与基础入口

入口菜单项：
1. `Open Clipboard`
2. `Settings`
3. `Quit ClipLite`

对应实现：`ClipLite/UI/MenuBar/StatusBarController.swift`

## 5.2 全局快捷键

当前热键是“预设枚举”，非自由录制：
1. `Command + ;`（默认）
2. `Command + Shift + V`
3. `Command + Option + Space`

行为规则：
1. 设置页切换预设后立即重注册。
2. 注册失败时自动回退到上一个可用预设并更新设置。

对应实现：
1. `ClipLite/Models/HotkeyPreset.swift`
2. `ClipLite/Core/Hotkey/HotkeyManager.swift`
3. `ClipLite/App/AppCoordinator.swift`

## 5.3 面板形态与定位

面板类型：
1. `NSPanel`，`styleMask` 包含 `.nonactivatingPanel`。
2. `canBecomeKey = true`，`canBecomeMain = false`。
3. `windowDidResignKey` 时自动关闭。

显示定位策略：
1. 优先读取当前聚焦输入元素 AX frame。
2. 面板优先出现在锚点右侧，超边界时夹紧到屏幕可见区域。
3. 无法定位时回退到顶部居中。

尺寸：
1. 窗口约 `748 x 372`。
2. 左侧列表 `360`，右侧详情 `380`。

对应实现：
1. `ClipLite/Core/Panel/ClipboardPanel.swift`
2. `ClipLite/Core/Panel/ClipboardPanelController.swift`
3. `ClipLite/Core/Panel/InputAnchorLocator.swift`

## 5.4 面板键盘与鼠标交互

面板层键盘拦截（`NSEvent.addLocalMonitorForEvents(.keyDown)`）：
1. `↑` / `↓`：移动选中。
2. `Enter`：确认并执行粘贴。
3. `Esc`：按优先级处理（关闭预览 -> 退出搜索 -> 关闭面板）。
4. `1..9`：快速选择并粘贴（搜索模式下禁用）。
5. `⌘F`：进入搜索并聚焦搜索框。
6. `Space`：切换当前选中项预览（搜索框聚焦时不拦截）。

鼠标交互：
1. 单击选中。
2. 双击直接粘贴。
3. 悬停延迟预览（约 900ms）。

对应实现：
1. `ClipLite/Core/Panel/PanelKeyEventRouter.swift`
2. `ClipLite/App/AppCoordinator.swift`
3. `ClipLite/UI/Panel/ClipboardPanelView.swift`

## 5.5 列表、筛选、搜索、预览

列表能力：
1. 默认按时间倒序显示（最新在前）。
2. 支持筛选：`All` / `Text` / `Image`。
3. 支持关键词搜索（命中 `textContent` 与 `textPreview`）。

详情区：
1. 文本项显示完整文本详情。
2. 图片项显示大图预览，优先加载原图，失败回退缩略图。

对应实现：
1. `ClipLite/UI/Panel/ClipboardPanelViewModel.swift`
2. `ClipLite/UI/Panel/ClipboardPanelView.swift`

## 5.6 剪贴板监听与入库

监听机制：
1. 轮询 `NSPasteboard.general.changeCount`。
2. 默认轮询间隔 `0.12s`。
3. 检测到跳变时触发 burst 轮询（`0.06s * 16`）以捕获连续复制。
4. 解析和入库在后台队列执行。

解析规则：
1. 优先解析图片（PNG -> TIFF -> `NSImage(pasteboard:)`）。
2. 图片入库前尽量转 PNG 编码。
3. 再解析文本（`.string`）。

去重与过滤：
1. 连续重复去重（比较最新一条 hash，可开关）。
2. 空白文本过滤（可开关）。
3. 文本换行规范化（CRLF/CR -> LF）。

自循环保护：
1. 粘贴执行时记录自写回 `changeCount`。
2. 监听器遇到该 `changeCount` 会忽略，避免回写内容被再次入库。

对应实现：
1. `ClipLite/Core/Clipboard/ClipboardMonitor.swift`
2. `ClipLite/Core/Clipboard/ClipboardParser.swift`
3. `ClipLite/Core/Storage/HistoryStore.swift`

## 5.7 粘贴执行（Enter 核心链路）

执行顺序：
1. 将选中项写回系统剪贴板。
2. 检查 Accessibility 权限（可触发系统提示）。
3. 已授权则注入 `Cmd + V`。
4. 未授权或注入失败则降级为“仅复制”。

图片回写策略：
1. 优先 `writeObjects([NSImage])`。
2. 失败时尝试写入 TIFF。

对应实现：
1. `ClipLite/Core/Clipboard/PasteExecutor.swift`
2. `ClipLite/Core/Permissions/AccessibilityPermissionService.swift`

## 5.8 设置窗口

设置项：
1. `Launch at login`。
2. `Global Shortcut`（预设选择）。
3. `Theme`（Follow System / Light / Dark）。
4. `Max history items`（50...5000，步长 50）。
5. `Retention days`（1...365）。
6. `Ignore consecutive duplicates`。
7. `Ignore whitespace text`。

窗口行为：
1. 打开设置时激活应用并聚焦窗口。
2. 单窗口实例复用。
3. 关闭时仅 `orderOut`，不退出进程。

对应实现：
1. `ClipLite/UI/Settings/SettingsRootView.swift`
2. `ClipLite/UI/Settings/SettingsWindowController.swift`
3. `ClipLite/Core/Settings/SettingsManager.swift`

## 5.9 开机自启

实现：
1. 通过 `SMAppService.mainApp.register()/unregister()` 开关。
2. 调用失败会在设置页显示错误。

对应实现：`ClipLite/Core/Settings/StartupManager.swift`

---

## 6. 数据模型与存储

## 6.1 应用层模型

`ClipItem` 字段：
1. `id: UUID`
2. `type: ClipType`（`text` / `image`）
3. `createdAt: Date`
4. `hashValue: String`
5. `textContent: String?`
6. `textPreview: String`
7. `imagePath: String?`
8. `thumbnailPath: String?`
9. `fileSize: Int64?`
10. `imageWidth: Int?`
11. `imageHeight: Int?`

`AppSettings` 字段：
1. `launchAtLogin: Bool`
2. `hotkeyPreset: HotkeyPreset`
3. `themeMode: ThemeMode`
4. `maxItemCount: Int`
5. `maxRetentionDays: Int`
6. `ignoreConsecutiveDuplicates: Bool`
7. `ignoreWhitespaceText: Bool`

## 6.2 SQLite 表结构（当前实现）

```sql
CREATE TABLE IF NOT EXISTS clip_history (
    id TEXT PRIMARY KEY,
    type INTEGER NOT NULL,
    content TEXT,
    text_preview TEXT,
    image_path TEXT,
    thumbnail_path TEXT,
    file_size INTEGER,
    image_width INTEGER,
    image_height INTEGER,
    created_at REAL NOT NULL,
    hash_value TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_clip_history_created_at
ON clip_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clip_history_hash
ON clip_history(hash_value);
```

说明：
1. 当前 schema 不包含 `source_app_bundle_id/source_app_name` 字段。
2. `SQLiteManager` 内置缺失列迁移逻辑（`ALTER TABLE` 补列）。

## 6.3 文件目录结构

```text
~/Library/Application Support/ClipLite/
├── Database/
│   └── clips.sqlite
└── Images/
    ├── originals/
    └── thumbnails/
```

说明：
1. 原图文件名：`<UUID>.png`。
2. 缩略图文件名：`<UUID>.jpg`。
3. SQLite 只保存相对路径，读取时解析为绝对路径。

---

## 7. 架构与模块边界

1. `AppCoordinator`：应用组装、模块协同、状态流转。
2. `StatusBarController`：菜单栏入口。
3. `HotkeyManager`：全局热键注册与回调。
4. `ClipboardMonitor`：轮询监听与入库触发。
5. `HistoryStore`：业务级入库、去重、清理。
6. `SQLiteManager`：SQLite 访问与 schema。
7. `FileStorage`：原图/缩略图文件写删。
8. `CleanupService`：清理任务调度。
9. `ClipboardPanelController`：`NSPanel` 生命周期与展示。
10. `PanelKeyEventRouter`：面板级键盘路由。
11. `ClipboardPanelViewModel`：列表状态、筛选、搜索、预览缓存。
12. `PasteExecutor`：剪贴板回写 + `Cmd + V` 注入。
13. `SettingsManager`：`UserDefaults` 持久化与变更通知。
14. `StartupManager`：开机自启开关。

---

## 8. 线程与调度模型

1. 主线程：AppKit/SwiftUI 交互、窗口和面板控制。
2. `ClipboardMonitor.processingQueue`：剪贴板解析后的入库处理。
3. `HistoryStore.queue`：SQLite 与文件存储串行访问。
4. `CleanupService.queue`：清理任务异步执行。
5. `ClipboardPanelViewModel.thumbnailLoadQueue`：图片缩略图/预览加载。

---

## 9. 权限与降级策略

1. 自动粘贴依赖 Accessibility 权限。
2. 权限未授予时：不阻断复制，返回“仅复制”路径。
3. 输入框锚点定位同样依赖 Accessibility；无权限则回退固定位置。

---

## 10. 测试与验证（当前仓库）

2026-03-02 实测：
1. `swift build` 通过。
2. `swift build -c release` 通过。
3. `swift test` 通过（15 tests, 0 failures）。

已覆盖方向：
1. 路径安全（`AppPaths`）。
2. burst 轮询捕获连续复制（`ClipboardMonitor`）。
3. 历史拉取策略边界（`HistoryFetchPolicy`）。
4. `HistoryStore` 文本入库/去重/按数量清理。
5. `SQLiteManager` 按时间与数量清理。
6. 滚轮事件过滤策略。

---

## 11. 已知限制与后续优先项

1. 热键仅支持预设，不支持任意组合录制。
2. 自动粘贴兼容性仍需更完整跨应用回归。
3. 输入框锚点定位需要更多多屏/边界场景验证。
4. 未打通签名、公证、升级发布链路。
5. 历史管理功能（删除/置顶/收藏）仍缺失。

---

## 12. 常用开发命令

1. 构建 Debug：`swift build`
2. 构建 Release：`swift build -c release`
3. 运行测试：`swift test`
4. 本地打包：`./scripts/package_app.sh`

产物：
1. `dist/ClipLite.app`
2. `dist/ClipLite-unsigned.zip`

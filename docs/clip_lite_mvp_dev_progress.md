# ClipLite MVP 开发进度文档（实现对齐版）

## 1. 文档目的
记录当前代码仓库中已经落地的 MVP 能力、与目标需求的对照、已知缺口和下一步优先项。

关联文档：`clip_lite_mvp_doc.md`

---

## 2. 当前实现快照（截至 2026-03-02）

已完成主链路：
1. Agent 形态菜单栏应用：`LSUIElement = YES`，`NSApplication` 使用 `.accessory` 激活策略。
2. 全局快捷键唤起面板（Carbon `RegisterEventHotKey`，默认 `Command + ;`）。
3. 热键预设切换（`Command + ;` / `Command + Shift + V` / `Command + Option + Space`），注册失败自动回退上一可用预设。
4. 非激活 `NSPanel`（`nonactivatingPanel`）作为历史面板，失焦自动关闭。
5. 面板定位优先跟随当前聚焦输入元素（Accessibility），失败时回退顶部居中。
6. 面板交互：`↑`/`↓` 选择，`Enter` 执行粘贴，`Esc` 逐级退出（预览 -> 搜索 -> 面板），`1..9` 快速粘贴，`⌘F` 聚焦搜索，`Space` 预览开关。
7. 鼠标交互：单击选中、双击粘贴、悬停延迟预览。
8. 列表能力：文本/图片混合历史、底部筛选（All/Text/Image）、搜索过滤。
9. 右侧详情区：文本详情气泡 + 图片大图预览。
10. 回车粘贴链路：写回系统剪贴板 -> 权限检查 -> 注入 `Cmd + V`；失败时降级为“仅复制”。
11. 剪贴板监听：`NSPasteboard.changeCount` 轮询（基础 0.12s + burst 0.06s * 16），支持自写回 `changeCount` 忽略，防止自循环。
12. 存储：SQLite 元数据 + 本地文件（原图/缩略图），文本与图片都支持入库。
13. 去重与过滤：连续重复去重、空白文本过滤（均可在设置中开关）。
14. 清理机制：启动时立即清理 + 入库/设置变更后节流清理。
15. 设置窗口：开机自启、快捷键预设、主题、最大条数、保留天数、高级开关。
16. 打包能力：`scripts/package_app.sh` 产出 `dist/ClipLite.app` 与 `dist/ClipLite-unsigned.zip`。

---

## 3. 构建与测试状态（2026-03-02 实测）

执行结果：
1. `swift build`：通过。
2. `swift build -c release`：通过。
3. `swift test`：通过（15 tests, 0 failures）。

当前已有测试文件：
1. `Tests/ClipLiteTests/AppPathsTests.swift`
2. `Tests/ClipLiteTests/ClipboardMonitorTests.swift`
3. `Tests/ClipLiteTests/HistoryFetchPolicyTests.swift`
4. `Tests/ClipLiteTests/HistoryStoreIntegrationTests.swift`
5. `Tests/ClipLiteTests/SQLiteManagerIntegrationTests.swift`
6. `Tests/ClipLiteTests/ScrollEventPolicyTests.swift`

---

## 4. 与 MVP 目标对照

### 4.1 已完成
1. 状态栏常驻与静默后台运行。
2. 全局快捷键唤起面板，默认选中第一条。
3. 文本与图片历史保存、展示与选择。
4. `↑`/`↓`/`Enter`/`Esc` 键盘主链路稳定可用。
5. 数字键 `1..9` 快速粘贴。
6. `Enter` 自动粘贴及权限降级路径。
7. 存储上限与保留天数配置并生效。
8. 跟随系统/浅色/深色主题切换。
9. 设置窗口单例化显示。
10. 启动清理 + 节流清理。
11. 面板输入框锚点定位（可用时生效）。
12. 搜索过滤与类型筛选（超出最初 MVP 但已实现）。
13. 右侧详情预览（文本/图片）。

### 4.2 部分完成
1. 开机自启：代码已接入 `SMAppService`，但在未签名分发场景下仍需实机验证稳定性。
2. 自动粘贴兼容性：核心链路完成，尚缺系统化跨应用回归报告。
3. 输入框锚点定位：实现已落地，仍需多应用/多显示器边界测试。

### 4.3 未完成（发布与增强）
1. 正式签名、公证、自动升级与发布流程。
2. 任意快捷键录制式输入（当前仅支持预设组合）。
3. 历史项管理操作（删除/置顶/收藏等）与更多编辑能力。

---

## 5. 当前代码结构与关键入口

### 5.1 App 协调
1. `ClipLite/App/ClipLiteMain.swift`
2. `ClipLite/App/AppDelegate.swift`
3. `ClipLite/App/AppCoordinator.swift`

### 5.2 核心模块
1. 热键：`ClipLite/Core/Hotkey/HotkeyManager.swift`
2. 面板：
`ClipLite/Core/Panel/ClipboardPanel.swift`
`ClipLite/Core/Panel/ClipboardPanelController.swift`
`ClipLite/Core/Panel/PanelKeyEventRouter.swift`
`ClipLite/Core/Panel/InputAnchorLocator.swift`
3. 剪贴板：
`ClipLite/Core/Clipboard/ClipboardMonitor.swift`
`ClipLite/Core/Clipboard/ClipboardParser.swift`
`ClipLite/Core/Clipboard/PasteExecutor.swift`
4. 存储：
`ClipLite/Core/Storage/SQLiteManager.swift`
`ClipLite/Core/Storage/HistoryStore.swift`
`ClipLite/Core/Storage/FileStorage.swift`
`ClipLite/Core/Storage/CleanupService.swift`
5. 图片：`ClipLite/Core/Image/ThumbnailGenerator.swift`
6. 设置与权限：
`ClipLite/Core/Settings/SettingsManager.swift`
`ClipLite/Core/Settings/StartupManager.swift`
`ClipLite/Core/Permissions/AccessibilityPermissionService.swift`

### 5.3 UI
1. 菜单栏：`ClipLite/UI/MenuBar/StatusBarController.swift`
2. 面板：
`ClipLite/UI/Panel/ClipboardPanelView.swift`
`ClipLite/UI/Panel/ClipboardPanelViewModel.swift`
3. 设置：
`ClipLite/UI/Settings/SettingsWindowController.swift`
`ClipLite/UI/Settings/SettingsRootView.swift`

---

## 6. 已知问题与体验缺口

1. 快捷键仍为“预设模式”，没有按键录制与冲突解释 UI。
2. 自动粘贴尚未形成完整跨应用兼容性矩阵。
3. 面板视觉与动效还有打磨空间（状态反馈、搜索高亮、空结果引导）。
4. 发布链路未打通（签名、公证、分发、升级）。
5. 历史管理操作还不完整（删除/固定/清空策略细化）。

---

## 7. 下一阶段建议

1. 完成跨应用回归：Safari/Chrome/Notes/VS Code/微信或飞书/Telegram/Terminal。
2. 增加按键录制式热键配置与冲突提示。
3. 补齐历史管理能力（删除单条、批量清理、快捷操作）。
4. 完成签名、公证、安装与升级策略。

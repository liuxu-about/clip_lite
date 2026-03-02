# ClipLite MVP 开发进度文档

## 1. 文档目的
记录 ClipLite MVP 当前实现状态、与原始需求文档的对照情况、已知缺口和后续开发计划，作为后续迭代的统一上下文。

关联设计文档：`clip_lite_mvp_doc.md`

---

## 2. 当前实现快照（截至本次会话）

已完成的主链路：
1. 状态栏常驻应用（Agent 形态）
2. 全局快捷键唤起面板（设置页可配置，默认 `Command + ;`）
3. 非激活 `NSPanel` + 面板层键盘事件路由（`↑ ↓ Enter Esc`、`1..9` 快速粘贴、`⌘F` 搜索）+ 鼠标双击粘贴 + 鼠标悬停跟随选中
4. `Enter` 触发：写回系统剪贴板 + `Cmd + V` 注入 + 权限降级
5. 剪贴板监听与入库：文本 + 图片
6. SQLite 元数据存储 + 图片原图/缩略图本地文件存储
7. 连续重复去重、自写回剪贴板防自循环
8. 设置窗口（通用设置、存储策略、主题、开机自启开关）
9. 清理机制（启动清理 + 入库后节流清理）
10. 面板 UI 紧凑化 + 右侧详情区（文本详情/图片大图预览）+ 毛玻璃效果
11. 应用图标与状态栏图标接入（`AppIcon.icns`、`StatusBarIconTemplate.png`）
12. 面板锚点定位：优先跟随当前聚焦输入控件，默认显示在其右下；失败时回退顶部居中
13. 本地测试包产物（`dist/ClipLite.app`, `dist/ClipLite-unsigned.zip`）与统一打包脚本（`scripts/package_app.sh`）

当前编译状态：`swift build` 通过，`swift build -c release` 通过。

---

## 3. 与需求文档对照

### 3.1 已完成
1. 状态栏常驻与后台运行形态
2. 非激活面板唤起
3. 默认选中第一条
4. 面板键盘操作 `↑ ↓ Enter Esc`、`1..9` 快速粘贴、`⌘F` 搜索 + 鼠标双击粘贴 + 悬停选中
5. 文本历史保存与展示
6. 图片历史保存、缩略图展示
7. Enter 自动粘贴及权限降级路径
8. 存储上限和保留时间配置
9. 跟随系统/浅色/深色主题切换
10. 设置窗口单例化显示
11. 面板右侧详情预览（文本详情、图片大图预览）
12. 应用图标与状态栏图标资源化接入

### 3.2 部分完成
1. 开机自启
说明：代码已接入 `SMAppService`，但在未正式签名/正式 App Bundle 发布场景下稳定性待验证。

2. 自动粘贴兼容性
说明：核心链路已可用，但尚未完成系统化跨应用回归测试与细化兼容策略。

3. 面板“跟随输入框”定位
说明：已实现基于 Accessibility 的聚焦控件锚点定位（右下方优先），但仍需跨应用实测与边界策略微调。

### 3.3 未完成
1. 完整发布流程
说明：尚未完成正式签名/公证/发布渠道流程。

---

## 4. 当前代码结构与关键入口

### 4.1 App 与协调层
1. `ClipLite/App/ClipLiteMain.swift`
2. `ClipLite/App/AppDelegate.swift`
3. `ClipLite/App/AppCoordinator.swift`

### 4.2 核心能力
1. 热键：`ClipLite/Core/Hotkey/HotkeyManager.swift`
2. 面板：
`ClipLite/Core/Panel/ClipboardPanel.swift`
`ClipLite/Core/Panel/ClipboardPanelController.swift`
`ClipLite/Core/Panel/PanelKeyEventRouter.swift`
3. 剪贴板监听/解析/粘贴：
`ClipLite/Core/Clipboard/ClipboardMonitor.swift`
`ClipLite/Core/Clipboard/ClipboardParser.swift`
`ClipLite/Core/Clipboard/PasteExecutor.swift`
4. 存储：
`ClipLite/Core/Storage/SQLiteManager.swift`
`ClipLite/Core/Storage/HistoryStore.swift`
`ClipLite/Core/Storage/FileStorage.swift`
`ClipLite/Core/Storage/CleanupService.swift`
5. 图片：`ClipLite/Core/Image/ThumbnailGenerator.swift`
6. 设置：
`ClipLite/Core/Settings/SettingsManager.swift`
`ClipLite/Core/Settings/StartupManager.swift`

### 4.3 UI
1. 菜单栏：`ClipLite/UI/MenuBar/StatusBarController.swift`
2. 面板：
`ClipLite/UI/Panel/ClipboardPanelView.swift`
`ClipLite/UI/Panel/ClipboardPanelViewModel.swift`
3. 设置窗口：
`ClipLite/UI/Settings/SettingsWindowController.swift`
`ClipLite/UI/Settings/SettingsRootView.swift`

---

## 5. 已知问题与体验缺口

1. 热键能力仍是“预设组合切换”
影响：目前可在 UI 中切换预设组合，但尚未支持“按键录制式”的任意组合输入与冲突提示 UI。

2. 面板体验仍偏工程版
影响：已完成一轮紧凑化和详情区改造，但信息分组、过渡动画与状态反馈仍可提升。

3. 兼容性验证不足
影响：不同输入目标（浏览器、IM、编辑器）中的自动粘贴稳定性还需系统回归。

4. 发布链路未完成
影响：当前只能本地测试安装，不适合正式分发。

5. 搜索交互仍可继续打磨
影响：已支持 `⌘F` 进入搜索栏筛选，但结果高亮、搜索历史与空结果引导仍有提升空间。

6. 图标主题能力尚未配置化
影响：目前已接入一套图标资源，但尚未提供图标主题切换与模板图自动生成工具链。

---

## 6. 下一阶段开发计划

### 阶段 A（已完成）
目标：补齐“快捷键弹窗体验”的核心缺口。

已完成任务：
1. 增加快捷键配置能力（设置页可修改预设热键）
2. 默认值切换到 `Command + ;`
3. 修改后热键即时生效并持久化
4. 增加最小可行冲突处理（注册失败自动回退上一个可用热键）

### 阶段 B
目标：稳定性与兼容性强化。

任务：
1. 跨应用粘贴回归测试（Safari/Chrome/Notes/VS Code/微信或飞书/Terminal）
2. 图片粘贴兼容策略微调（类型声明、降级路径）
3. 权限引导文案与交互打磨
4. 输入框锚点定位回归（多应用、多显示器、边界避让）
5. 异常日志补齐（按模块可追踪）

### 阶段 C
目标：发布准备。

任务：
1. Xcode App Target 正式整理
2. 正式签名与公证流程
3. 安装包与升级策略
4. 基础回归测试清单固化

---

## 7. 当前可用的测试方式

1. 编译：`swift build`
2. Release 构建：`swift build -c release`
3. 一键打包（含图标资源拷贝）：`./scripts/package_app.sh`
4. 本地安装包：
`dist/ClipLite.app`
`dist/ClipLite-unsigned.zip`

首次体验建议：
1. 启动后确认菜单栏图标存在
2. 使用 `Command + ;` 唤起面板（可在设置页改为其他预设）
3. 复制文本与图片后验证历史项展示
4. 在文本输入框聚焦状态下唤起面板，验证面板优先出现在输入框右下附近（失败回退顶部居中）
5. 按 `Enter` 验证自动粘贴与降级行为

---

## 8. 下一次会话建议先做什么

1. 做跨应用“输入框锚点定位 + 自动粘贴”联合回归（Safari/Chrome/Notes/VS Code/IM/Terminal）
2. 继续打磨搜索体验（结果高亮、空结果提示、搜索历史）
3. 补“按键录制式”快捷键输入与冲突提示 UI
4. 进入签名/公证/发布链路准备

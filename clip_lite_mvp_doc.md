# macOS 剪贴板工具 MVP 完整框架文档（V1.1）

## 1. 文档信息

**项目名称（暂定）**
ClipLite（可替换）

**文档版本**
V1.1

**目标读者**
AI coding 工具 / 工程开发者 / 你自己作为产品与架构确认者

**开发目标**
先做一个可稳定使用的 macOS 状态栏剪贴板工具 MVP，重点打通这条链路：

全局快捷键唤起面板 → 默认选中第一条 → 键盘上下选择 → 回车直接粘贴到当前输入位置

---

## 2. 产品定位与目标

### 2.1 产品定位

一个常驻状态栏的 macOS 轻量级剪贴板历史工具，强调键盘优先、简洁美观、后台无感运行，界面风格接近 CleanClip Pro 的极简模式。

### 2.2 MVP 核心目标

1. 全局快捷键快速唤起历史列表
2. 支持文本和图片历史
3. 默认选中最新项，回车直接粘贴
4. 开机自启，静默运行，不弹主界面
5. 可配置最大存储数量和最大存储时间
6. 跟随 macOS 深浅色主题，支持手动切换

### 2.3 MVP 非目标

以下功能不进入本期 MVP

1. iCloud 同步
2. OCR
3. 收藏夹、标签、分类系统
4. 富文本编辑器
5. 团队协作
6. 浏览器扩展
7. 多设备同步
8. 高级规则引擎

---

## 3. 关键用户场景

### 3.1 快速回填文本

用户刚复制一段文本，按快捷键弹出列表，默认在第一条，按回车即可粘贴到当前输入框。

### 3.2 复用截图或图片

用户复制了一张截图，在列表中看到缩略图，选中后按回车，图片能粘贴到聊天软件或文档中。

### 3.3 静默后台运行

用户开机后工具自动运行，无 Dock 图标，不打开主界面，只在菜单栏驻留，随时可调用。

### 3.4 控制占用

用户希望限制历史条数和保存时间，避免磁盘和内存占用增长过快。

---

## 4. 产品形态与运行模式

## 4.1 应用形态

状态栏常驻应用（Menu Bar App）

## 4.2 静默运行要求

必须满足以下要求：

1. 启动时不显示主窗口
2. Dock 不显示图标
3. Cmd Tab 切换列表不出现本应用
4. 提供菜单栏图标作为入口

## 4.3 关键配置

在 `Info.plist` 中设置：

* `Application is agent (UIElement)` = `YES`
* 对应键名为 `LSUIElement`

这是实现静默状态栏工具形态的基础条件。

---

## 5. 技术选型与平台约束

## 5.1 技术栈

1. **语言**：Swift
2. **UI**：SwiftUI + AppKit 混合
3. **存储**：SQLite + 本地文件系统
4. **图片处理**：AppKit / ImageIO
5. **快捷键**：KeyboardShortcuts（第三方库，MVP 推荐）
6. **开机自启**：`SMAppService`（macOS 13+）
7. **系统剪贴板**：`NSPasteboard`
8. **模拟粘贴事件**：`CGEvent`（依赖辅助功能权限）

## 5.2 最低系统版本建议

建议 `macOS 13.0+`

原因：

1. `SMAppService` 更稳定
2. SwiftUI 与 AppKit 互操作体验更成熟
3. 便于后续扩展设置界面与状态栏交互

---

## 6. MVP 功能规格说明

## 6.1 全局快捷键唤起面板

### 功能描述

用户按下全局快捷键后，弹出剪贴板历史面板。

### 行为要求

1. 面板应在屏幕中央偏上位置显示（MVP 固定位置）
2. 默认选中第一条（最新一条）
3. 面板出现后可立即响应键盘上下和回车
4. `Esc` 关闭面板
5. 面板点击外部区域自动关闭（可配置，MVP 默认开启）

### MVP 默认快捷键

建议默认值：`Command + Shift + V`
后续在设置中支持自定义

---

## 6.2 历史列表展示（文本与图片）

### 支持类型

1. 文本
2. 图片（PNG、TIFF 等可识别图片内容）

### 排序规则

最新记录在前（按创建时间倒序）

### 列表项展示规范

#### 文本项

1. 显示文本预览（单行或双行截断）
2. 去除极端空白噪声（配置项可控）
3. 可显示来源应用图标或名称（MVP 可先不显示）

#### 图片项

1. 显示缩略图
2. 显示文件大小（如 `61 KB`）
3. 可显示尺寸信息（后续增强，MVP 可选）

### 关键性能要求

列表只加载缩略图，不直接加载原图

---

## 6.3 键盘交互（MVP 必做）

### 支持按键

1. `↑` 选择上一条
2. `↓` 选择下一条
3. `Enter` 选择并执行粘贴
4. `Esc` 关闭面板

### MVP 暂不支持

1. 搜索输入
2. 数字键直选
3. 复杂快捷操作（置顶、删除、收藏）

说明：先把焦点链路和直接粘贴链路做稳，搜索作为下一阶段扩展。

---

## 6.4 回车直接粘贴（核心链路）

### 目标体验

用户在当前应用输入框中工作，唤起面板后选择历史项并按回车，内容直接粘贴到原输入位置。

### MVP 实现链路

1. 将选中内容写入 `NSPasteboard.general`
2. 关闭面板
3. 使用 `CGEvent` 向系统发送 `Cmd + V`
4. 目标应用接收粘贴操作

### 权限要求

需要辅助功能权限（Accessibility）

### 降级策略（必须实现）

如果自动粘贴链路失败，至少保证以下结果：

1. 内容已写回系统剪贴板
2. 面板关闭
3. 给出轻量提示，提示用户手动 `Cmd + V`

### 失败场景分类

#### 明确失败场景

1. 未授予辅助功能权限
2. `CGEvent` 创建失败
3. 事件发送失败（可检测到）

#### 不明确失败场景

1. Secure Input 环境
2. 目标应用拦截合成事件
3. 目标输入框状态异常

对于不明确失败场景，MVP 不做强判断，只保证剪贴板回写成功并提供兼容性提示路径。

---

## 6.5 后台静默运行与开机自启

### 后台运行要求

1. App 启动后驻留后台
2. 仅菜单栏图标可见
3. 不自动弹设置窗口

### 开机自启要求

1. 支持开机登录自动启动
2. 启动后静默运行
3. 不显示主界面

### 技术实现

使用 `SMAppService.mainApp.register()` 注册登录项（macOS 13+）

---

## 6.6 存储策略配置（你重点关注）

### 可配置项

1. 最大存储数量（例如 100 / 300 / 1000 / 自定义）
2. 最大存储时间（例如 7 天 / 30 天 / 90 天 / 自定义）

### 清理触发时机

1. App 启动时
2. 检测到新剪贴板内容入库后（节流执行）
3. 定时后台清理（例如每小时一次，可选）

### 清理规则

删除满足任一条件的记录：

1. 超出最大数量的旧记录
2. 超出最大存储时间的记录

同时删除相关文件：

1. 原图文件
2. 缩略图文件

---

## 6.7 主题与外观

### 主题模式

1. 跟随系统（默认）
2. 浅色
3. 深色

### 实现要求

优先使用 SwiftUI 语义颜色与系统材料背景：

1. `.primary`
2. `.secondary`
3. `.ultraThinMaterial` 等

这样能自动适配深浅色切换，减少手写主题分支逻辑。

---

## 6.8 设置界面（MVP 范围）

### 入口

菜单栏菜单中的“设置”

### 设置窗口行为

1. 打开设置窗口时激活应用
2. 关闭设置窗口后应用回到后台状态
3. 单窗口实例，重复点击只聚焦已有窗口

### MVP 设置项

1. **常规**

   * 登录时启动（Toggle）
   * 主题模式（跟随系统 / 浅色 / 深色）
2. **快捷键**

   * 唤起面板快捷键设置（使用 KeyboardShortcuts 提供的组件）
3. **存储**

   * 最大历史条数
   * 最大保留天数
4. **高级（可选）**

   * 忽略连续重复复制（Toggle）
   * 忽略空白文本（Toggle）

---

## 7. macOS 深水区实现决策（关键避坑）

这部分是给 AI coding 工具的重点约束，请严格遵守。

## 7.1 面板必须使用 `NSPanel`，并设置为非激活面板

目标是尽量不打断当前应用的输入上下文。

### 要求

1. `styleMask` 包含 `.nonactivatingPanel`
2. 显示时调用 `panel.makeKeyAndOrderFront(nil)`
3. 快捷面板场景下不调用 `NSApp.activate(...)`

### 目的

面板获取键盘事件处理能力，同时尽量不把 App 切到前台激活状态。

---

## 7.2 非激活面板下的键盘事件处理，不依赖 SwiftUI List 默认行为

这是重点中的重点。

### 原因

SwiftUI `List` 在 `NSPanel` 中对方向键和回车响应可能受焦点链影响，不稳定。

### 决策

1. 键盘事件在面板层统一处理
2. SwiftUI 视图只做渲染与状态绑定
3. 面板层负责：

   * `↑`
   * `↓`
   * `Enter`
   * `Esc`

### 建议实现方式

1. 自定义 `NSPanel` 子类
2. 配合 `NSResponder` 或本地事件监听处理 `keyDown`
3. 将操作转换为 ViewModel 状态更新

---

## 7.3 自定义 `NSPanel` 子类要求

建议至少满足以下行为：

1. `canBecomeKey = true`
2. `canBecomeMain = false`
3. 支持点击外部自动关闭（看交互配置）
4. 关闭时清理事件监听器

---

## 7.4 自动粘贴兼容性策略

不要假设 `Cmd + V` 注入在所有应用都稳定成功。

### 必须实现

1. 权限检查与引导
2. 自动粘贴失败时保留剪贴板结果
3. 用户仍然可以手动粘贴

### MVP 不做

1. 对 Secure Input 的精确检测
2. 对目标应用粘贴成功与否的可靠回执判断

说明：macOS 没有稳定的公共 API 提供粘贴成功回执。

---

## 8. 系统权限与用户引导

## 8.1 辅助功能权限（Accessibility）

用途：

1. 发送合成键盘事件 `Cmd + V`

### 引导策略

建议在用户首次使用回车直接粘贴时执行：

1. 检查权限状态
2. 未授权时提示用户去系统设置开启权限
3. 提供“继续仅复制模式”的降级路径

---

## 8.2 剪贴板访问说明

普通剪贴板读取通常不需要额外系统权限弹窗。
仍建议在设置或首次启动提示中告知用户本工具会本地保存剪贴板历史。

---

## 9. 技术架构设计

## 9.1 总体架构

单进程状态栏应用，后台轮询监听系统剪贴板变化，数据持久化到 SQLite 与本地文件系统，快捷面板使用 `NSPanel + SwiftUI` 展示。

## 9.2 模块划分

### 1. AppCoordinator

职责：

1. 应用生命周期管理
2. 初始化各模块
3. 协调菜单栏、面板、设置窗口

### 2. StatusBarController

职责：

1. 创建菜单栏图标
2. 构建菜单项
3. 响应打开设置、清空历史、退出等操作

### 3. HotkeyManager

职责：

1. 注册全局快捷键
2. 响应快捷键事件
3. 通知面板显示或隐藏

实现建议：
使用 `KeyboardShortcuts`

### 4. ClipboardMonitor

职责：

1. 轮询 `NSPasteboard.general.changeCount`
2. 检测剪贴板变化
3. 解析文本和图片内容
4. 执行基础过滤与去重
5. 提交给存储层

### 5. HistoryStore

职责：

1. SQLite 元数据读写
2. 图片原图和缩略图文件管理
3. 查询历史列表
4. 清理过期与超量数据

### 6. ThumbnailGenerator

职责：

1. 图片入库时生成缩略图
2. 控制缩略图尺寸与压缩质量
3. 异步执行，避免阻塞主线程

### 7. ClipboardPanelController

职责：

1. 管理 `NSPanel`
2. 显示/隐藏面板
3. 管理键盘事件路由
4. 与 SwiftUI 内容视图绑定

### 8. PanelKeyEventRouter

职责：

1. 面板层拦截方向键、回车、Esc
2. 更新选中索引
3. 触发粘贴或关闭动作

### 9. PasteExecutor

职责：

1. 将选中历史项写回 `NSPasteboard`
2. 发送 `Cmd + V` 事件
3. 处理权限检查与降级逻辑

### 10. SettingsManager

职责：

1. 管理用户配置
2. `UserDefaults` 持久化
3. 配置变化广播

### 11. StartupManager

职责：

1. 管理开机自启注册状态
2. 对外提供开关接口

---

## 9.3 线程与队列模型

### 主线程

1. 菜单栏 UI
2. 面板显示与交互
3. 设置窗口

### 后台串行队列（建议）

1. 剪贴板解析任务
2. 去重 hash 计算
3. 图片原图落盘
4. 缩略图生成
5. 数据入库
6. 清理任务

### 数据库队列

SQLite 写操作建议串行执行，避免并发冲突。

---

## 10. 数据模型设计

## 10.1 核心实体 `ClipItem`

建议字段（应用层）：

* `id: UUID`
* `type: ClipType`（`text` / `image`）
* `createdAt: Date`
* `hashValue: String`
* `textContent: String?`
* `textPreview: String?`
* `imagePath: String?`
* `thumbnailPath: String?`
* `fileSize: Int64?`
* `imageWidth: Int?`
* `imageHeight: Int?`
* `sourceAppBundleId: String?`（可选）
* `sourceAppName: String?`（可选）

---

## 10.2 SQLite 表结构（MVP 推荐）

```sql
CREATE TABLE IF NOT EXISTS clip_history (
    id TEXT PRIMARY KEY,
    type INTEGER NOT NULL,                 -- 0=text, 1=image
    content TEXT,                          -- 文本内容
    text_preview TEXT,                     -- 文本预览
    image_path TEXT,                       -- 原图相对路径
    thumbnail_path TEXT,                   -- 缩略图相对路径
    file_size INTEGER,                     -- bytes
    image_width INTEGER,
    image_height INTEGER,
    source_app_bundle_id TEXT,
    source_app_name TEXT,
    created_at REAL NOT NULL,              -- UNIX timestamp
    hash_value TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_clip_history_created_at
ON clip_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_clip_history_hash
ON clip_history(hash_value);
```

---

## 10.3 配置模型 `AppSettings`

建议字段：

* `launchAtLogin: Bool`
* `themeMode: ThemeMode`（followSystem / light / dark）
* `maxItemCount: Int`
* `maxRetentionDays: Int`
* `hotkey: ShortcutDefinition`
* `ignoreConsecutiveDuplicates: Bool`
* `ignoreWhitespaceText: Bool`

---

## 10.4 本地文件目录结构

应用支持目录（示例）：

```text
~/Library/Application Support/ClipLite/
├── Database/
│   └── clips.sqlite
├── Images/
│   ├── originals/
│   └── thumbnails/
└── Logs/   (可选，开发阶段)
```

说明：

1. 图片文件名建议使用 `UUID` 或 `hash + timestamp`
2. 数据库存相对路径，便于迁移

---

## 11. 剪贴板监听与存储策略

## 11.1 监听方案

使用 `Timer` 轮询 `NSPasteboard.general.changeCount`

### 建议轮询策略（MVP）

1. 默认 500ms 轮询
2. 检测到变化后立即把解析任务丢到后台队列
3. 避免在主线程做 hash 和图片处理

### 备注

后续可做空闲节流，例如在长时间无变化时放宽到 800ms 或 1000ms。

---

## 11.2 内容解析规则（MVP）

### 文本

1. 优先读取纯文本类型
2. 可配置忽略空白文本
3. 生成预览文本（截断到一定长度）

### 图片

1. 读取图片对象或图片数据
2. 保存原图文件
3. 生成缩略图文件
4. 记录文件大小、尺寸信息

---

## 11.3 去重策略（MVP）

默认开启“连续重复去重”

### 文本去重

对文本内容计算 hash
建议基于规范化文本进行 hash（例如统一换行，可选 trim 尾部空白）

### 图片去重

对图片二进制内容计算 hash
不要基于文件路径做 hash

### 连续重复判断

仅与最新一条比较，hash 相同则忽略新增记录

这样能避免误伤正常工作流中的重复复用。

---

## 11.4 清理策略（数量与时间双阈值）

清理满足任一条件的旧记录：

1. 超过 `maxItemCount`
2. 早于 `now - maxRetentionDays`

### 清理触发时机

1. App 启动时执行一次
2. 入库后节流执行
3. 可选定时执行（每小时）

### 清理步骤

1. 查询需要删除的记录列表
2. 删除 SQLite 元数据
3. 删除原图文件
4. 删除缩略图文件
5. 忽略不存在文件错误，记录日志即可

---

## 12. 快捷面板与焦点控制设计（核心章节）

## 12.1 设计目标

在不明显打断当前应用输入上下文的前提下，让面板能够响应键盘导航和回车确认。

## 12.2 面板类型

使用 `NSPanel`，设置 `.nonactivatingPanel`

## 12.3 显示策略

快捷键触发后执行：

1. 构建或复用面板实例
2. 刷新列表数据
3. 设置选中索引为 `0`
4. `panel.makeKeyAndOrderFront(nil)`

### 注意事项

快捷面板显示时，不调用 `NSApp.activate(...)`

---

## 12.4 键盘事件路由策略（必须）

键盘事件在面板层处理，不依赖 SwiftUI `List` 默认键盘行为。

### 支持的面板级事件

1. `UpArrow`
2. `DownArrow`
3. `Return`
4. `Escape`

### 行为映射

1. `UpArrow`：`selectedIndex = max(0, selectedIndex - 1)`
2. `DownArrow`：`selectedIndex = min(lastIndex, selectedIndex + 1)`
3. `Return`：触发 `PasteExecutor`
4. `Escape`：关闭面板

---

## 12.5 SwiftUI 视图职责边界

SwiftUI 视图仅负责：

1. 列表渲染
2. 选中态显示
3. 点击条目触发选择
4. 缩略图异步展示

不要把方向键与回车核心逻辑绑死在 SwiftUI 视图层。

---

## 13. 粘贴执行器设计（PasteExecutor）

## 13.1 功能职责

1. 将选中记录写回系统剪贴板
2. 发送 `Cmd + V` 键盘事件
3. 权限检查与提示
4. 失败降级

---

## 13.2 写入剪贴板规则

### 文本

使用 `NSPasteboard.general.setString(_, forType: .string)`
必要时补充更多文本表示

### 图片

建议使用以下方式之一（按兼容性优先级）：

1. `writeObjects([NSImage])`
2. 或显式写入 PNG / TIFF 数据类型，如 `.png` / `.tiff`

要求：
明确声明图片类型，避免聊天软件或富文本输入框识别失败。

---

## 13.3 模拟 `Cmd + V` 实现要求

使用 `CGEvent` 发送按键按下与抬起事件。

### 约束

1. 使用 Carbon 键码常量，不写死裸十六进制数值
2. 发送顺序正确
3. 在面板关闭后发送事件（减少事件命中面板自身的风险）

---

## 13.4 权限处理与降级

### 权限不足

1. 弹出引导提示
2. 说明需要开启辅助功能权限才能自动粘贴
3. 保持内容已写入剪贴板

### 兼容性异常

1. 不强行重试多次
2. 保持剪贴板已写入
3. 轻提示用户手动粘贴

---

## 14. UI 设计规范（MVP）

## 14.1 风格目标

1. 简洁
2. 清晰
3. 现代 macOS 原生风格
4. 深浅色一致性好

## 14.2 快捷面板布局建议

1. 顶部可不放搜索框（MVP 暂不做搜索）
2. 中间为列表区域
3. 底部提示操作键（可选）

### 面板尺寸建议（初版）

* 宽度：520 到 640 pt
* 高度：根据列表项数量限制在 360 到 520 pt

### 列表项高度建议

1. 文本项：48 到 60 pt
2. 图片项：72 到 92 pt（含缩略图）

---

## 14.3 选中态要求

1. 高亮明显
2. 深浅色下对比度足够
3. 键盘切换时有稳定的视觉反馈
4. 默认第一项高亮

---

## 14.4 设置界面布局建议

采用左侧导航 + 右侧表单的结构，风格接近你提供的 CleanClip Pro 截图，但功能更精简。

---

## 15. 设置窗口行为规范（LSUIElement 模式下）

由于 `LSUIElement = YES`，设置窗口行为需要单独定义。

### 15.1 打开设置窗口

从菜单栏点击“设置”时：

1. 显式激活应用
2. 显示或聚焦设置窗口

### 15.2 关闭设置窗口

设置窗口关闭后：

1. 应用继续驻留后台
2. 菜单栏保持可用
3. 不退出应用

### 15.3 单例窗口

MVP 只保留一个设置窗口实例，重复打开只聚焦现有窗口。

---

## 16. 项目结构建议（给 AI coding 工具）

```text
ClipLite/
├── App/
│   ├── ClipLiteApp.swift
│   ├── AppDelegate.swift
│   ├── AppCoordinator.swift
│   └── EnvironmentContainer.swift
├── Core/
│   ├── Hotkey/
│   │   └── HotkeyManager.swift
│   ├── Clipboard/
│   │   ├── ClipboardMonitor.swift
│   │   ├── ClipboardParser.swift
│   │   └── PasteExecutor.swift
│   ├── Panel/
│   │   ├── ClipboardPanel.swift              // NSPanel subclass
│   │   ├── ClipboardPanelController.swift
│   │   └── PanelKeyEventRouter.swift
│   ├── Storage/
│   │   ├── HistoryStore.swift
│   │   ├── SQLiteManager.swift
│   │   ├── ClipRepository.swift
│   │   ├── FileStorage.swift
│   │   └── CleanupService.swift
│   ├── Image/
│   │   └── ThumbnailGenerator.swift
│   ├── Settings/
│   │   ├── SettingsManager.swift
│   │   └── StartupManager.swift
│   └── Permissions/
│       └── AccessibilityPermissionService.swift
├── UI/
│   ├── MenuBar/
│   │   └── StatusBarController.swift
│   ├── Panel/
│   │   ├── ClipboardPanelViewModel.swift
│   │   ├── ClipboardPanelView.swift
│   │   ├── ClipRowView.swift
│   │   └── ThumbnailImageView.swift
│   └── Settings/
│       ├── SettingsWindowController.swift
│       ├── SettingsRootView.swift
│       ├── GeneralSettingsView.swift
│       ├── HotkeySettingsView.swift
│       └── StorageSettingsView.swift
├── Models/
│   ├── ClipItem.swift
│   ├── ClipType.swift
│   ├── AppSettings.swift
│   └── ThemeMode.swift
├── Utilities/
│   ├── Hashing.swift
│   ├── Logger.swift
│   ├── Date+Extensions.swift
│   └── ByteCountFormatter+Extensions.swift
└── Resources/
    ├── Assets.xcassets
    └── Info.plist
```

---

## 17. 开发约束与编码规范（给 AI coding 工具）

## 17.1 开发原则

1. 优先保证核心链路稳定
2. UI 与逻辑解耦
3. 面板键盘事件逻辑集中管理
4. 所有耗时操作放后台队列
5. 所有系统集成点（权限、自启、CGEvent）做好错误处理

## 17.2 错误处理原则

1. 不因单条剪贴板解析失败导致监听中断
2. 不因缩略图生成失败阻断原图保存
3. 自动粘贴失败时保留剪贴板回写结果
4. 文件删除失败记录日志并继续清理后续项

## 17.3 日志建议（开发期）

建议使用统一 `Logger` 封装，日志级别至少包含：

1. debug
2. info
3. warning
4. error

建议重点记录：

1. 快捷键触发
2. 面板显示与关闭
3. 剪贴板变化解析结果
4. 入库结果
5. 清理结果
6. 自动粘贴权限与执行结果

---

## 18. 核心流程定义（时序视角）

## 18.1 App 启动流程

1. 启动 App（LSUIElement 模式）
2. 初始化 `SettingsManager`
3. 初始化 `StatusBarController`
4. 初始化 `HistoryStore`
5. 初始化 `ClipboardMonitor`
6. 注册全局快捷键
7. 执行一次清理任务
8. 开始轮询监听剪贴板

---

## 18.2 剪贴板监听入库流程

1. `Timer` 检测 `changeCount` 变化
2. 变化后将解析任务派发到后台队列
3. 判断类型（文本 / 图片）
4. 计算 hash
5. 连续重复去重
6. 文本生成预览或图片落盘
7. 图片异步生成缩略图
8. 写入 SQLite 元数据
9. 通知 UI 可刷新缓存（若面板打开）
10. 节流触发清理任务

---

## 18.3 快捷面板唤起与选择流程

1. 用户按全局快捷键
2. 加载最近历史列表
3. `selectedIndex = 0`
4. 面板 `makeKeyAndOrderFront(nil)`
5. 面板层开始接管键盘导航键
6. 用户 `↑ ↓` 切换
7. 用户按 `Enter`
8. 触发 `PasteExecutor`
9. 面板关闭

---

## 18.4 粘贴执行流程

1. 检查选中项是否有效
2. 写入 `NSPasteboard`
3. 检查辅助功能权限
4. 权限不足则提示并结束（剪贴板已回写）
5. 关闭面板
6. 发送 `Cmd + V` 合成事件
7. 记录结果日志
8. 若异常则给出轻量提示（已复制，可手动粘贴）

---

## 18.5 打开设置窗口流程

1. 用户点击菜单栏菜单“设置”
2. 显式激活 App
3. 创建或聚焦设置窗口
4. 用户修改配置后保存到 `UserDefaults`
5. 配置变化通知相关模块生效
6. 关闭窗口后回到后台驻留状态

---

## 19. 权限与兼容性策略清单

## 19.1 必须支持

1. 未授权辅助功能权限时的提示与降级
2. 常见文本输入框的自动粘贴
3. 常见聊天软件和文档软件的图片粘贴兼容（至少具备基础可用性）

## 19.2 兼容性说明（MVP）

以下场景可能存在限制，MVP 允许以降级行为处理：

1. Secure Input 环境
2. 特殊沙盒应用对事件注入拦截
3. 部分富文本编辑器对图片类型识别差异

---

## 20. 性能目标与资源占用目标（MVP）

### 20.1 体验目标

1. 快捷键唤起面板到可操作时间小于 100ms（常见机器）
2. 500 条历史记录时列表滚动流畅
3. 图片历史滚动不出现明显卡顿

### 20.2 空闲资源目标（建议）

1. 空闲 CPU 占用尽量低
2. 空闲内存占用保持轻量
3. 轮询与图片处理不阻塞主线程

---

## 21. 测试计划（MVP）

## 21.1 功能测试

1. 文本复制入库
2. 图片复制入库
3. 快捷键唤起面板
4. 默认选中第一条
5. 上下键切换
6. Enter 自动粘贴
7. Esc 关闭
8. 开机自启
9. 存储数量清理
10. 存储时间清理
11. 深浅色切换
12. 设置项保存与重启恢复

## 21.2 兼容性测试（建议优先）

至少测试以下目标应用中的输入框：

1. Safari / Chrome 输入框
2. Notes
3. VS Code 编辑区
4. 微信 / 飞书 / Telegram 聊天输入框（你常用哪个就优先测哪个）
5. Terminal（普通输入场景）

## 21.3 异常测试

1. 未授予辅助功能权限时按 Enter
2. 连续快速复制大量文本
3. 大图复制与缩略图生成
4. 删除文件失败容错
5. SQLite 写入异常容错（模拟）

---

## 22. MVP 验收标准（交付门槛）

满足以下条件即可认为 MVP 可用：

1. 状态栏常驻，启动后无 Dock 图标
2. 快捷键可稳定唤起面板
3. 面板默认选中第一条
4. `↑ ↓ Enter Esc` 稳定可用
5. 文本与图片历史都能保存和展示
6. Enter 能在常见应用里直接粘贴（存在兼容性差异时有降级路径）
7. 可配置最大历史数量与保留天数，并实际生效
8. 开机自启可用，且静默运行
9. 深浅色模式可切换并正常显示
10. 长时间后台运行无明显卡顿或异常崩溃

---

## 23. 开发里程碑建议（给 AI coding 工具拆任务）

## 里程碑 1：核心链路 PoC

目标是验证最难的焦点与粘贴链路

任务：

1. `LSUIElement` 状态栏应用形态
2. 菜单栏图标与退出菜单
3. 全局快捷键注册
4. `NSPanel` 非激活面板
5. 假数据列表
6. 面板层键盘事件（↑ ↓ Enter Esc）
7. `NSPasteboard` 文本写入
8. `CGEvent` `Cmd + V` 注入
9. 权限提示与降级

完成后先手测，确认这条链路稳定再继续。

---

## 里程碑 2：真实剪贴板监听与入库

任务：

1. `ClipboardMonitor` 轮询
2. 文本解析与入库
3. SQLite 持久化
4. 面板读取真实数据展示
5. 连续重复去重

---

## 里程碑 3：图片支持

任务：

1. 图片解析与原图落盘
2. 缩略图生成与缓存
3. 图片项展示
4. 图片回写剪贴板与粘贴兼容性测试

---

## 里程碑 4：设置与自启

任务：

1. 设置窗口
2. 快捷键设置
3. 存储策略设置
4. 主题设置
5. `SMAppService` 开机自启
6. 清理任务实现

---

## 里程碑 5：打磨与发布准备

任务：

1. 异常处理与日志完善
2. UI 细节打磨
3. 性能优化
4. 兼容性测试
5. 打包与签名流程（按你后续发布方式决定）

---

24. 给 AI coding 工具的执行指令模板（可直接贴）

请按以下约束实现一个 macOS 剪贴板工具 MVP（Swift，SwiftUI + AppKit）：

【目标】
实现状态栏常驻剪贴板工具，支持文本和图片历史。支持全局快捷键唤起非激活面板，默认选中第一条，支持 ↑ ↓ Enter Esc，按 Enter 将选中内容写入系统剪贴板并通过 CGEvent 发送 Cmd+V 自动粘贴。支持开机自启、静默运行、最大条数与保留天数配置、深浅色主题切换。

【关键工程与配置约束（严格遵守）】
1. Info.plist 设置 LSUIElement = YES。
2. 必须在 Xcode 项目设置中关闭 App Sandbox（Target -> Signing & Capabilities -> 移除 App Sandbox），否则 CGEvent 将无法跨应用发送按键。
3. 快捷面板使用 NSPanel，styleMask 包含 .nonactivatingPanel。显示面板时调用 makeKeyAndOrderFront(nil)，绝对不要调用 NSApp.activate。
4. 剪贴板自循环防抖：程序自身回写 NSPasteboard 时，必须记录此时的 changeCount，并在 ClipboardMonitor 轮询时忽略此 changeCount，防止将程序自己的回写当作新复制记录入库。
5. 键盘事件拦截：由于 NSHostingView 会吞噬事件，请在面板显示时使用 `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` 拦截 ↑、↓、Enter、Esc 并处理焦点逻辑（处理后返回 nil），面板隐藏时移除该 Monitor。不要依赖 SwiftUI List 的默认键盘行为。

【核心业务约束】
1. 粘贴执行必须包含权限检查（AXIsProcessTrusted），若未授权则跳过 CGEvent 注入，保留剪贴板回写结果并给予提示。
2. 图片采用原图 + 缩略图双存储，列表 UI 仅加载缩略图。
3. 剪贴板监听使用 NSPasteboard.general.changeCount + Timer 轮询（默认 500ms），解析与入库在 Dispatch 工作队列异步执行。
4. 数据存储使用 SQLite（存储元数据）+ Application Support 本地文件（存储图片）。
5. 设置窗口打开时允许显式激活 App (NSApp.activate)，关闭后 App 需继续保持后台 agent 驻留状态。

【第一阶段必须完成的 PoC (最小可行性验证)】
1. 状态栏常驻（无 Dock 图标）。
2. 全局快捷键唤起非激活 NSPanel。
3. 面板假数据列表支持 ↑ ↓ Enter Esc 完美响应。
4. Enter 后文本写入系统剪贴板并成功通过 CGEvent 发送 Cmd+V 到前台 App。

输出可编译的 Xcode 工程代码骨架与第一阶段 PoC 的关键代码实现，所有耗时任务放后台队列，所有系统调用包含错误捕获与日志。先实现 MVP，不要添加额外功能。

---

## 25. 后续扩展方向（MVP 之后）

这一段给你留作下一轮规划，当前不进入开发范围。

1. 搜索过滤
2. 数字键直选
3. 置顶收藏
4. 暂停记录
5. 忽略敏感应用
6. 光标附近弹出面板
7. 多格式支持（文件、富文本等）
8. 云同步

---


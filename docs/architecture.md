# ClipLite 架构说明

## 项目定位

ClipLite 是一个 macOS 菜单栏剪贴板历史工具，当前聚焦以下能力：

- 菜单栏常驻运行，不占用 Dock
- 通过全局快捷键打开非激活历史面板
- 支持文本与图片历史记录
- 支持筛选、搜索、预览和回车粘贴
- 使用 SQLite 保存元数据，并用本地文件保存图片资源
- 提供开机自启、主题、热键预设和存储策略设置

当前未覆盖的方向：

- iCloud / 多端同步
- OCR
- 任意快捷键录制
- 正式签名、公证、自动更新发布链路
- 更完整的历史管理操作（如收藏、置顶、批量管理）

## 核心流程

1. `ClipboardMonitor` 监听 `NSPasteboard.general.changeCount`。
2. `ClipboardParser` 解析文本或图片内容。
3. `HistoryStore` 负责业务级过滤、去重与清理调度。
4. `SQLiteManager` 与 `FileStorage` 分别持久化元数据和图片文件。
5. `HotkeyManager` 触发 `AppCoordinator` 展示历史面板。
6. `ClipboardPanelViewModel` 管理筛选、搜索、选中态和预览。
7. `PasteExecutor` 将选中项写回剪贴板，并尝试注入 `Cmd + V`；失败时降级为“仅复制”。

## 模块划分

- `ClipLite/App`：应用生命周期、依赖组装、主流程协调
- `ClipLite/Core/Clipboard`：剪贴板监听、解析、粘贴执行
- `ClipLite/Core/Storage`：SQLite、文件存储、清理策略
- `ClipLite/Core/Panel`：非激活面板、键盘路由、定位逻辑
- `ClipLite/Core/Hotkey`：全局热键注册与切换
- `ClipLite/Core/Settings`：用户设置与开机自启
- `ClipLite/Core/Permissions`：辅助功能权限检查
- `ClipLite/Core/Image`：图片缩略图与预览支持
- `ClipLite/UI`：菜单栏、面板、设置窗口界面
- `ClipLite/Models` 与 `ClipLite/Utilities`：共享模型与通用工具

## 存储模型

- SQLite 数据库位置：`~/Library/Application Support/ClipLite/Database/clips.sqlite`
- 图片原图目录：`~/Library/Application Support/ClipLite/Images/originals/`
- 图片缩略图目录：`~/Library/Application Support/ClipLite/Images/thumbnails/`

设计原则：

- 元数据放入 SQLite，便于排序、过滤和清理
- 图片二进制文件单独落盘，避免数据库膨胀
- 清理逻辑按“最大条数”和“保留天数”共同生效

## 权限与运行约束

- 最低系统版本：`macOS 13+`
- 自动粘贴依赖辅助功能权限（Accessibility）
- 输入框锚点定位同样依赖辅助功能权限；无权限时回退到固定位置
- 历史面板使用非激活 `NSPanel`，尽量不打断当前前台应用
- 当前热键配置是预设枚举，不是自由录制模式

## 常用开发命令

```bash
swift build
swift build -c release
swift test
./scripts/package_app.sh
```

## 当前已知限制

- 自动粘贴还需要更多跨应用兼容性验证
- 多显示器和复杂输入框场景下的锚点定位仍有继续打磨空间
- 还没有正式的签名、公证和自动升级流程
- 历史项管理能力目前仍以“查看、选择、粘贴”为主

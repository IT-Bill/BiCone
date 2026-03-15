# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **App Review Demo（iOS）**: 登录页新增 App Review Demo 入口，为 TestFlight / App Review 预置演示账号、订阅、视频列表与下载状态
- **演示下载流程**: 审核模式下支持模拟下载、暂停、继续与完成通知，便于在无真实 Bilibili 账号的前提下验证核心功能
- **审核说明文档**: 新增 `APP_REVIEW_NOTES.md`，可直接复制到 App Store Connect 的审核备注中

### Changed
- 审核模式下禁用实时监控与新增真实订阅入口，避免依赖外部账号和二维码扫描

## [0.2.4] - 2026-03-04

### Added
- **失效视频处理**: 下载失败时区分"视频已失效或网络异常"，弹窗提供"重试"和"标记为失效"按钮
- **已失效视频管理**: 视频动态页左上角菜单新增"显示已失效视频"选项，已失效视频显示橙色"已失效"标签，支持重试下载或删除
- **删除前有效性检查**: 删除已完成视频时通过 RSSHub 检查源站状态，失效时警告用户删除后可能无法再下载，有效时显示"视频状态：正常"
- **新视频本地通知**: 检测到新视频时发送本地推送通知，包含 UP主名称、视频标题和自动下载状态

### Changed
- 默认检查间隔从 30 分钟改为 3 分钟

### Fixed
- 修复应用清除后台后登录状态丢失（网络异常时不再清除已保存的登录凭据）

## [0.2.3] - 2026-03-04

### Changed
- 版本号升级至 0.2.3
- 新增 CHANGELOG.md，梳理历史版本变更记录

## [0.2.2] - 2026-03-04

### Added
- **系统文件选择器**: 下载路径改用 `FilePicker` 原生文件夹选择器，Android/Windows 均可用
- **强制首次设置下载路径**: 下载前必须选择文件夹，移除默认路径 fallback
- **权限错误提示**: 检测 `PathAccessException` 并弹出友好提示引导用户更换路径

### Fixed
- 修复 RSS 503 错误（URL 双斜杠问题 + 502/503/504 自动重试）
- 修复添加订阅需多次点击确认（增加 public card API fallback + 输入校验）
- 修复下载无法启动及无法重试（Android 存储权限 + 目录自动创建）

## [0.2.1] - 2026-03-04

### Added
- **视频动态页改版**: UP主 Tab 筛选 + 双列网格布局
- **视频删除与忽略机制**: 支持删除已下载视频并标记为已忽略，可在菜单中切换显示
- **已忽略视频恢复**: AppBar 菜单支持显示/隐藏已忽略视频，支持一键恢复
- **自动下载仅限新视频**: 仅自动下载订阅后发布的新视频，历史视频需手动下载
- **时间显示优化**: 1小时内→分钟前，当天→小时前，当年→MM-DD，跨年→YYYY-MM-DD，统一 UTC+8
- **标题固定两行高度**: 短标题留白，长标题省略号截断
- 添加 1 分钟和 3 分钟检查间隔选项

### Fixed
- 修复下载取消后状态卡死（持久化更新 `StorageService` 状态）
- 修复 compact 卡片空白过大（移除 `Spacer()` 和 `Expanded`）
- 修复卡片底部多余空白（`mainAxisSize: MainAxisSize.min`）
- 修复切换检查间隔后界面不立即更新（setter 未调用 `notifyListeners()`）

### Changed
- 底部 Tab 标签「动态」改为「视频」
- 视频网格宽高比多次调优至 0.82
- 下载状态统一在卡片底部显示，移除缩略图右上角状态徽章
- 已下载标记（✅）放在垃圾桶图标左侧

## [0.2.0] - 2025-07-17

### Added
- **Cupertino 风格全面重构**: 全部 UI 从 Material 3 迁移到 iOS Cupertino 风格
  - `CupertinoApp` + `CupertinoThemeData` (biliPink #FB7299 主色调)
  - `CupertinoPageScaffold` + `CupertinoNavigationBar` + `CupertinoSlidingSegmentedControl`
  - `CupertinoListSection.insetGrouped` + `CupertinoSwitch` + `CupertinoActionSheet`
  - 自定义 `_CircularProgressPainter` 替代 Material 进度指示器
  - 所有页面统一使用 `CupertinoIcons`
- **浮动液态玻璃底部导航栏**: `BackdropFilter` 毛玻璃效果，大圆角悬浮设计，半透明背景
- **视频动态按时间倒序排列**: 支持 ISO 8601 和 RFC 1123 格式的时间解析

### Fixed
- 修复设置页账号头像/昵称不显示（改用公开 API 获取用户信息）
- 修复中断下载后视频卡住问题（启动时自动清理残留状态和部分文件）

## [0.1.0] - 2025-07-17

### Added
- **Bilibili 扫码登录**: QR 码生成与轮询登录，SESSDATA/bili_jct 令牌持久化，应用重启自动恢复登录
- **订阅管理**: 通过 UID 添加 UP主 订阅（WBI 签名），订阅列表展示（头像、昵称、UID、签名），支持取消订阅
- **视频监控**: 通过 RSSHub 定期监控新视频，可配置检查间隔（5/10/15/30/60/120 分钟）
- **视频下载**: Bilibili API 获取视频流（360P~1080P60），队列式下载管理，进度显示与取消
- **Material 3 UI**: Bilibili 粉色主题，亮/暗色模式，4 个主页面（视频动态、订阅管理、下载管理、设置）
- **三端应用图标**: 从 `icon.png` 生成 Android（5 种密度）、Windows（多尺寸 ico）、iOS（15 个尺寸）图标
- **下载路径管理**: 设置页显示实际路径，已完成下载支持复制路径和复制目录
- **上次检查信息移至视频动态页**

### Fixed
- 修复 RSS 视频解析（缩略图正则精确匹配 img 标签，BV ID 提取增加 fallback）
- 修复 Web 平台网络错误（添加 `kIsWeb` 检测，区分 CORS 错误与普通网络错误）

### Changed
- 项目从 Hamster 重命名为 Squirrel，所有平台配置同步更新
- Android 网络配置：RSSHub 默认地址适配模拟器，允许明文 HTTP

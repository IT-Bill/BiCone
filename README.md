<h1 align="center">BiCone</h1>

<p align="center"><b>Bilibili 专属的「防失效」追更神器</b></p>
<p align="center">一键订阅 ⚡ 自动监测 ⚡ 更新通知 ⚡ 自动缓存</p>
<p align="center">不错过 UP 主的每一次更新，彻底告别"视频已失效"的遗憾。</p>

<p align="center">
  [<a href="https://github.com/IT-Bill/BiCone/releases/latest">下载安装</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/docs/README.zh-TW.md">繁體中文</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/docs/README.en.md">English</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/docs/README.ja.md">日本語</a>]
</p>

<p align="center">
  <a href="https://github.com/IT-Bill/BiCone/blob/main/LICENSE"><img src="https://img.shields.io/github/license/IT-Bill/BiCone.svg?style=flat&colorA=080f12&colorB=1fa669&label=%E5%BC%80%E6%BA%90%E5%8D%8F%E8%AE%AE" alt="开源协议"></a>
  <a href="https://github.com/IT-Bill/BiCone/releases/latest"><img src="https://img.shields.io/github/v/release/IT-Bill/BiCone?style=flat&colorA=080f12&colorB=1fa669&label=%E7%89%88%E6%9C%AC" alt="版本"></a>
  <img src="https://img.shields.io/badge/%E5%B9%B3%E5%8F%B0-Android%20%7C%20Windows-blue?style=flat&colorA=080f12&colorB=1fa669" alt="平台">
  <a href="https://github.com/IT-Bill/BiCone/actions/workflows/release-android.yml"><img src="https://img.shields.io/github/actions/workflow/status/IT-Bill/BiCone/release-android.yml?style=flat&colorA=080f12&label=Android" alt="Android CI"></a>
  <a href="https://github.com/IT-Bill/BiCone/actions/workflows/release-windows.yml"><img src="https://img.shields.io/github/actions/workflow/status/IT-Bill/BiCone/release-windows.yml?style=flat&colorA=080f12&label=Windows" alt="Windows CI"></a>
  <img src="https://img.shields.io/badge/Flutter-%E2%89%A53.41-02569B?style=flat&logo=flutter&colorA=080f12" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%E2%89%A53.11.1-0175C2?style=flat&logo=dart&colorA=080f12" alt="Dart">
</p>

<!-- 建议在此放置一张应用主界面截图或演示 GIF -->
<!-- ![BiCone 截图](docs/images/screenshot.png) -->

> [!NOTE]
> BiCone 目前支持 **Android** 和 **Windows** 平台，iOS 版本将在后续开发。

> [!WARNING]
> 本项目及相关代码仅供技术研究和学习探讨，工具本身不提供任何受版权保护的内容。用户在使用本工具时，需自行确保遵守相关法律法规，特别是与版权相关的法律条款。开发者不对因使用本工具而产生的任何版权纠纷或法律责任承担责任。请用户在使用时谨慎，确保其行为合法合规，并仅在有合法授权的情况下使用相关内容。

## 功能特性

- **订阅 UP 主** — 添加你关注的 Bilibili UP 主，自动通过 RSSHub 监测更新
- **自动缓存** — 检测到新视频后自动下载到本地，无需手动操作
- **高速下载** — 支持多线程分段并行下载，速度可达 20MB/s 以上
- **多画质选择** — 支持 360P 至 4K 多种画质

- **下载管理** — 查看下载进度、暂停/继续、断点续传、管理已缓存的视频
- **跨平台** — Android 和 Windows 双平台支持

## 安装

### Android

从 [Releases](https://github.com/IT-Bill/BiCone/releases/latest) 页面下载对应架构的 APK：

- **arm64-v8a**（推荐，适用于大多数现代设备）
- **armeabi-v7a**（适用于较老的 32 位设备）

> [!TIP]
> 国内用户可访问 [Gitee Releases](https://gitee.com/IT-Bill/BiCone/releases/latest) 获得更快的下载速度。

### Windows

从 [Releases](https://github.com/IT-Bill/BiCone/releases/latest) 页面下载：

- **安装版**（`BiCone-x.x.x-windows-x64-setup.exe`）— 推荐，含桌面快捷方式
- **便携版**（`BiCone-x.x.x-windows-x64.zip`）— 解压即用，无需安装

> [!TIP]
> 国内用户可访问 [Gitee Releases](https://gitee.com/IT-Bill/BiCone/releases/latest) 获得更快的下载速度。

## 快速上手

### 1. 登录

打开应用后，使用 Bilibili 扫码登录以获取视频下载权限。

<!-- ![登录页](docs/images/login.png) -->

### 2. 添加订阅

进入「订阅」页面，点击右上角的 **+** 按钮，输入 UP 主的 UID 即可添加订阅。

<!-- ![添加订阅](docs/images/add_subscription.gif) -->

> [!NOTE]
> UP 主的 UID 可在其 Bilibili 个人主页的 URL 中找到，例如 `https://space.bilibili.com/12345678` 中的 `12345678`。

### 3. 查看动态

切换到「动态」页面，可以看到所有订阅 UP 主的最新视频。

<!-- ![动态页](docs/images/feed.png) -->

### 4. 下载视频

点击视频卡片即可手动下载，或在订阅设置中开启自动下载。

<!-- ![下载](docs/images/download.gif) -->

### 5. 设置

在「设置」页面可以调整：

- 视频画质偏好
- 下载存储路径
- 监测刷新间隔
- 通知开关

<!-- ![设置页](docs/images/settings.png) -->

## 开源协议

[MIT License](LICENSE)

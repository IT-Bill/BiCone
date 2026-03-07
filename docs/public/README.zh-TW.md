<h1 align="center">BiCone</h1>

<p align="center"><b>Bilibili 專屬的「防失效」追更神器</b></p>
<p align="center">一鍵訂閱 ⚡ 自動監測 ⚡ 更新通知 ⚡ 自動快取</p>
<p align="center">不錯過 UP 主的每一次更新，徹底告別「影片已失效」的遺憾。</p>

<p align="center">
  [<a href="https://github.com/IT-Bill/BiCone/releases/latest">下載安裝</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/README.md">简体中文</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/docs/README.en.md">English</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/docs/README.ja.md">日本語</a>]
</p>

<p align="center">
  <a href="https://github.com/IT-Bill/BiCone/blob/main/LICENSE"><img src="https://img.shields.io/github/license/IT-Bill/BiCone.svg?style=flat&colorA=080f12&colorB=1fa669&label=%E9%96%8B%E6%BA%90%E5%8D%94%E8%AD%B0" alt="開源協議"></a>
  <a href="https://github.com/IT-Bill/BiCone/releases/latest"><img src="https://img.shields.io/github/v/release/IT-Bill/BiCone?style=flat&colorA=080f12&colorB=1fa669&label=%E7%89%88%E6%9C%AC" alt="版本"></a>
  <img src="https://img.shields.io/badge/%E5%B9%B3%E5%8F%B0-Android%20%7C%20Windows-blue?style=flat&colorA=080f12&colorB=1fa669" alt="平台">
  <a href="https://github.com/IT-Bill/BiCone/actions/workflows/release-android.yml"><img src="https://img.shields.io/github/actions/workflow/status/IT-Bill/BiCone/release-android.yml?style=flat&colorA=080f12&label=Android" alt="Android CI"></a>
  <a href="https://github.com/IT-Bill/BiCone/actions/workflows/release-windows.yml"><img src="https://img.shields.io/github/actions/workflow/status/IT-Bill/BiCone/release-windows.yml?style=flat&colorA=080f12&label=Windows" alt="Windows CI"></a>
  <img src="https://img.shields.io/badge/Flutter-%E2%89%A53.41-02569B?style=flat&logo=flutter&colorA=080f12" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%E2%89%A53.11.1-0175C2?style=flat&logo=dart&colorA=080f12" alt="Dart">
</p>

<!-- 建議在此放置一張應用主介面截圖或演示 GIF -->
<!-- ![BiCone 截圖](docs/images/screenshot.png) -->

> [!NOTE]
> BiCone 目前支援 **Android** 和 **Windows** 平台，iOS 版本將在後續開發。

> [!WARNING]
> 本專案及相關程式碼僅供技術研究和學習探討，工具本身不提供任何受版權保護的內容。使用者在使用本工具時，需自行確保遵守相關法律法規，特別是與版權相關的法律條款。開發者不對因使用本工具而產生的任何版權糾紛或法律責任承擔責任。請使用者在使用時謹慎，確保其行為合法合規，並僅在有合法授權的情況下使用相關內容。

## 功能特性

- **訂閱 UP 主** — 新增你關注的 Bilibili UP 主，自動透過 RSSHub 監測更新
- **自動快取** — 偵測到新影片後自動下載到本機，無需手動操作
- **高速下載** — 支援多執行緒分段並行下載，速度可達 20MB/s 以上
- **多畫質選擇** — 支援 360P 至 4K 多種畫質
- **下載管理** — 檢視下載進度、暫停/繼續、斷點續傳、管理已快取的影片
- **跨平台** — Android 和 Windows 雙平台支援

## 安裝

### Android

從 [Releases](https://github.com/IT-Bill/BiCone/releases/latest) 頁面下載對應架構的 APK：

- **arm64-v8a**（推薦，適用於大多數現代裝置）
- **armeabi-v7a**（適用於較舊的 32 位元裝置）

> [!TIP]
> 中國大陸使用者可存取 [Gitee Releases](https://gitee.com/IT-Bill/BiCone/releases/latest) 獲得更快的下載速度。

### Windows

從 [Releases](https://github.com/IT-Bill/BiCone/releases/latest) 頁面下載：

- **安裝版**（`BiCone-x.x.x-windows-x64-setup.exe`）— 推薦，含桌面捷徑
- **便攜版**（`BiCone-x.x.x-windows-x64.zip`）— 解壓即用，無需安裝

> [!TIP]
> 中國大陸使用者可存取 [Gitee Releases](https://gitee.com/IT-Bill/BiCone/releases/latest) 獲得更快的下載速度。

## 快速上手

### 1. 登入

開啟應用後，使用 Bilibili 掃碼登入以取得影片下載權限。

<!-- ![登入頁](docs/images/login.png) -->

### 2. 新增訂閱

進入「訂閱」頁面，點擊右上角的 **+** 按鈕，輸入 UP 主的 UID 即可新增訂閱。

<!-- ![新增訂閱](docs/images/add_subscription.gif) -->

> [!NOTE]
> UP 主的 UID 可在其 Bilibili 個人主頁的 URL 中找到，例如 `https://space.bilibili.com/12345678` 中的 `12345678`。

### 3. 檢視動態

切換到「動態」頁面，可以看到所有訂閱 UP 主的最新影片。

<!-- ![動態頁](docs/images/feed.png) -->

### 4. 下載影片

點擊影片卡片即可手動下載，或在訂閱設定中開啟自動下載。

<!-- ![下載](docs/images/download.gif) -->

### 5. 設定

在「設定」頁面可以調整：

- 影片畫質偏好
- 下載儲存路徑
- 監測重新整理間隔
- 通知開關

<!-- ![設定頁](docs/images/settings.png) -->

## 開源協議

[MIT License](../LICENSE)

<h1 align="center">BiCone</h1>

<p align="center"><b>Bilibili 専用の「期限切れ防止」追っかけツール</b></p>
<p align="center">ワンタップ購読 ⚡ 自動監視 ⚡ 更新通知 ⚡ 自動キャッシュ</p>
<p align="center">UP 主の全ての更新を見逃さない——「動画は無効です」に永遠にさよなら。</p>

<p align="center">
  [<a href="https://github.com/IT-Bill/BiCone/releases/latest">ダウンロード</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/README.md">简体中文</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/docs/README.zh-TW.md">繁體中文</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/docs/README.en.md">English</a>]
</p>

<p align="center">
  <a href="https://github.com/IT-Bill/BiCone/blob/main/LICENSE"><img src="https://img.shields.io/github/license/IT-Bill/BiCone.svg?style=flat&colorA=080f12&colorB=1fa669" alt="License"></a>
  <a href="https://github.com/IT-Bill/BiCone/releases/latest"><img src="https://img.shields.io/github/v/release/IT-Bill/BiCone?style=flat&colorA=080f12&colorB=1fa669" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20Windows-blue?style=flat&colorA=080f12&colorB=1fa669" alt="Platform">
  <a href="https://github.com/IT-Bill/BiCone/actions/workflows/release-android.yml"><img src="https://img.shields.io/github/actions/workflow/status/IT-Bill/BiCone/release-android.yml?style=flat&colorA=080f12&label=Android" alt="Android CI"></a>
  <a href="https://github.com/IT-Bill/BiCone/actions/workflows/release-windows.yml"><img src="https://img.shields.io/github/actions/workflow/status/IT-Bill/BiCone/release-windows.yml?style=flat&colorA=080f12&label=Windows" alt="Windows CI"></a>
  <img src="https://img.shields.io/badge/Flutter-%E2%89%A53.11-02569B?style=flat&logo=flutter&colorA=080f12" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%E2%89%A53.11.1-0175C2?style=flat&logo=dart&colorA=080f12" alt="Dart">
</p>

<!-- メインUIのスクリーンショットやデモ GIF をここに配置してください -->
<!-- ![BiCone スクリーンショット](docs/images/screenshot.png) -->

> [!NOTE]
> BiCone は現在 **Android** と **Windows** をサポートしています。iOS 対応は今後のリリースで予定しています。

> [!WARNING]
> 本プロジェクトおよびそのコードは、技術研究および学習目的のみを対象としています。本ツール自体は著作権で保護されたコンテンツを提供しません。本ツールの使用において、ユーザーは関連する法令、特に著作権に関する法的規定を遵守する責任を負います。開発者は、本ツールの使用により生じたいかなる著作権紛争または法的責任についても一切の責任を負いません。合法的な範囲内で、適切な権限を得た上でご利用ください。

## 機能

- **UP 主を購読** — お気に入りの Bilibili クリエイターを追加し、RSSHub 経由で自動的に更新を監視
- **自動キャッシュ** — 新しい動画を検出すると自動でローカルにダウンロード
- **高速ダウンロード** — マルチスレッド並列ダウンロード対応、速度は 20MB/s 以上
- **画質選択** — 360P から 4K まで対応
- **ダウンロード管理** — ダウンロードの進行状況の確認、一時停止/レジューム対応、キャッシュ済み動画の管理
- **クロスプラットフォーム** — Android と Windows の両方に対応

## インストール

### Android

[Releases](https://github.com/IT-Bill/BiCone/releases/latest) ページからデバイスに対応する APK をダウンロードしてください：

- **arm64-v8a**（推奨、ほとんどの最新デバイス向け）
- **armeabi-v7a**（古い 32 ビットデバイス向け）

> [!TIP]
> 中国のユーザーは [Gitee Releases](https://gitee.com/IT-Bill/BiCone/releases/latest) からより高速にダウンロードできます。

### Windows

[Releases](https://github.com/IT-Bill/BiCone/releases/latest) ページからダウンロードしてください：

- **インストーラー版**（`BiCone-x.x.x-windows-x64-setup.exe`）— 推奨、デスクトップショートカット付き
- **ポータブル版**（`BiCone-x.x.x-windows-x64.zip`）— 解凍するだけ、インストール不要

> [!TIP]
> 中国のユーザーは [Gitee Releases](https://gitee.com/IT-Bill/BiCone/releases/latest) からより高速にダウンロードできます。

## クイックスタート

### 1. ログイン

アプリを開き、Bilibili で QR コードをスキャンしてログインし、動画ダウンロードを有効にします。

<!-- ![ログインページ](docs/images/login.png) -->

### 2. 購読の追加

「購読」タブに移動し、右上の **+** ボタンをタップして UP 主の UID を入力します。

<!-- ![購読追加](docs/images/add_subscription.gif) -->

> [!NOTE]
> UID はクリエイターの Bilibili プロフィール URL から確認できます。例：`https://space.bilibili.com/12345678` の `12345678`。

### 3. フィードを閲覧

「フィード」タブに切り替えると、購読中のすべての UP 主の最新動画が表示されます。

<!-- ![フィードページ](docs/images/feed.png) -->

### 4. 動画のダウンロード

動画カードをタップして手動ダウンロードするか、購読設定で自動ダウンロードを有効にします。

<!-- ![ダウンロード](docs/images/download.gif) -->

### 5. 設定

「設定」タブで以下を調整できます：

- 動画画質の設定
- ダウンロード保存先
- 監視更新間隔
- 通知のオン/オフ

<!-- ![設定ページ](docs/images/settings.png) -->

## ライセンス

[MIT License](../LICENSE)

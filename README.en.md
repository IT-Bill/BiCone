<h1 align="center">BiCone</h1>

<p align="center"><b>Your Bilibili "Anti-Expiry" Subscription Companion</b></p>
<p align="center">One-Tap Subscribe ⚡ Auto-Monitor ⚡ Push Notifications ⚡ Auto-Cache</p>
<p align="center">Never miss an update from your favorite creators — say goodbye to "video unavailable" forever.</p>

<p align="center">
  [<a href="https://github.com/IT-Bill/BiCone/releases/latest">Download</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/README.md">简体中文</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/README.zh-TW.md">繁體中文</a>] [<a href="https://github.com/IT-Bill/BiCone/blob/main/README.ja.md">日本語</a>]
</p>

<p align="center">
  <a href="https://github.com/IT-Bill/BiCone/blob/main/LICENSE"><img src="https://img.shields.io/github/license/IT-Bill/BiCone.svg?style=flat&colorA=080f12&colorB=1fa669" alt="License"></a>
  <a href="https://github.com/IT-Bill/BiCone/releases/latest"><img src="https://img.shields.io/github/v/release/IT-Bill/BiCone?style=flat&colorA=080f12&colorB=1fa669" alt="Release"></a>
  <img src="https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Windows-blue?style=flat&colorA=080f12&colorB=1fa669" alt="Platform">
  <a href="https://github.com/IT-Bill/BiCone/actions/workflows/release-android.yml"><img src="https://img.shields.io/github/actions/workflow/status/IT-Bill/BiCone/release-android.yml?style=flat&colorA=080f12&label=Android" alt="Android CI"></a>
  <a href="https://github.com/IT-Bill/BiCone/actions/workflows/release-windows.yml"><img src="https://img.shields.io/github/actions/workflow/status/IT-Bill/BiCone/release-windows.yml?style=flat&colorA=080f12&label=Windows" alt="Windows CI"></a>
  <img src="https://img.shields.io/badge/Flutter-%E2%89%A53.41-02569B?style=flat&logo=flutter&colorA=080f12" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%E2%89%A53.11.1-0175C2?style=flat&logo=dart&colorA=080f12" alt="Dart">
</p>

<!-- Consider placing a main UI screenshot or demo GIF here -->
<!-- ![BiCone Screenshot](docs/images/screenshot.png) -->

> [!NOTE]
> BiCone supports **Android**, **iOS** (TestFlight / self-signed IPA), and **Windows**.

> [!WARNING]
> This project and its code are intended solely for technical research and learning purposes. The tool itself does not provide any copyrighted content. Users must ensure compliance with applicable laws and regulations when using this tool, particularly those related to copyright. The developer assumes no responsibility for any copyright disputes or legal liabilities arising from the use of this tool. Please use it responsibly, ensure your actions are lawful, and only use related content with proper authorization.

## Features

- **Subscribe to Uploaders** — Add your favorite Bilibili creators and automatically monitor for new uploads via RSSHub
- **Auto-Cache** — Automatically download new videos to local storage, no manual effort needed
- **High-Speed Download** — Multi-threaded parallel download with speeds over 20MB/s
- **Quality Selection** — Choose from 360P to 4K
- **Download Manager** — View download progress, pause/resume with resume support, and manage cached videos
- **Push Notifications** — Get notified the moment a new video is published
- **Cross-Platform** — Available on Android, iOS, and Windows

## Installation

### Android

Download the APK for your device architecture from the [Releases](https://github.com/IT-Bill/BiCone/releases/latest) page:

- **arm64-v8a** (recommended for most modern devices)
- **armeabi-v7a** (for older 32-bit devices)

> [!TIP]
> Users in China can visit [Gitee Releases](https://gitee.com/IT-Bill/BiCone/releases/latest) for faster download speeds.

### iOS

- **TestFlight** (recommended) — Join the public beta via [TestFlight link](https://testflight.apple.com/join/PLACEHOLDER)
- **Self-signed IPA** — Download `unsigned.ipa` from [Releases](https://github.com/IT-Bill/BiCone/releases/latest) and sign with AltStore, Sideloadly, etc.

### Windows

Download from the [Releases](https://github.com/IT-Bill/BiCone/releases/latest) page:

- **Installer** (`BiCone-x.x.x-windows-x64-setup.exe`) — Recommended, includes desktop shortcut
- **Portable** (`BiCone-x.x.x-windows-x64.zip`) — Extract and run, no installation needed

> [!TIP]
> Users in China can visit [Gitee Releases](https://gitee.com/IT-Bill/BiCone/releases/latest) for faster download speeds.

## Quick Start

### 1. Login

Open the app and scan the QR code with Bilibili to sign in and enable video downloads.

<!-- ![Login Page](docs/images/login.png) -->

### 2. Add Subscriptions

Go to the "Subscriptions" tab, tap the **+** button in the top right, and enter the UP's UID.

<!-- ![Add Subscription](docs/images/add_subscription.gif) -->

> [!NOTE]
> You can find the UID in the creator's Bilibili profile URL, e.g., `12345678` in `https://space.bilibili.com/12345678`.

### 3. Browse Feed

Switch to the "Feed" tab to see the latest videos from all your subscribed creators.

<!-- ![Feed Page](docs/images/feed.png) -->

### 4. Download Videos

Tap a video card to download manually, or enable auto-download in subscription settings.

<!-- ![Download](docs/images/download.gif) -->

### 5. Settings

In the "Settings" tab you can adjust:

- Video quality preference
- Download storage path
- Monitor refresh interval
- Notification toggle

<!-- ![Settings Page](docs/images/settings.png) -->

## License

[MIT License](LICENSE)

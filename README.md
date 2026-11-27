<p align="center">
  <img src="./logo.svg" width="100" alt="Logo">                                       
</p>

<h3 align="center">Moler</h3>
<p align="center">NASA-Punk style macOS disk cleaner based on Mole • Native Swift GUI</p>

<p align="center">
  <b>English</b> · <a href="README_zh.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/niyongsheng/moler/releases"><img src="https://img.shields.io/github/v/release/niyongsheng/moler?style=for-the-badge&label=Release" alt="Release"></a>
  <a href="https://github.com/niyongsheng/moler"><img src="https://img.shields.io/badge/Swift-5.9-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift"></a>
  <a href="https://github.com/niyongsheng/moler"><img src="https://img.shields.io/badge/macOS-14.0+-005a9e?style=for-the-badge&logo=apple&logoColor=white" alt="macOS"></a>
  <a href="/LICENSE"><img src="https://img.shields.io/github/license/niyongsheng/moler?style=for-the-badge" alt="License"></a>
</p>

---

https://github.com/user-attachments/assets/61b2a73d-c8e4-4142-abf6-7effedb59791

## Features

| Module | Icon | Description |
|--------|------|-------------|
| **Overview** | 📊 | System health score, CPU/Memory/Network/Disk metrics, tool statistics |
| **Clean** | 🧹 | Deep scan directories, review results, and free up disk space |
| **Purge** | 🗑️ | Remove old Xcode, Gradle, CocoaPods, and other build artifacts |
| **Optimize** | 🔄 | Refresh system caches & services with **dry-run preview** support |
| **Analyze** | 🎛 | Disk usage treemap visualization — all items shown, **color-coded by file type** |
| **Software** | 📦 | Scan and uninstall applications with size info |

## Install

```bash
# Install via Homebrew
brew install --cask niyongsheng/moler/moler

# Remove quarantine attribute
sudo xattr -rd com.apple.quarantine /Applications/Moler.app
```

> [!IMPORTANT]  
> The `mo` CLI from [Mole](https://github.com/tw93/Mole) must be installed separately: `brew install mole`

## License

MIT © 2026 [Nico](https://github.com/niyongsheng)

<p align="center">
  <img src="./logo.svg" width="100" alt="Logo">                                       
</p>

<h3 align="center">Moler</h3>
<p align="center">基于 Mole 的 NASA-Punk 风格 macOS 磁盘清理工具 • 原生 Swift GUI</p>

<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

<p align="center">
  <a href="https://github.com/niyongsheng/moler/releases"><img src="https://img.shields.io/github/v/release/niyongsheng/moler?style=for-the-badge&label=Release" alt="Release"></a>
  <a href="https://github.com/niyongsheng/moler"><img src="https://img.shields.io/badge/Swift-5.9-FA7343?style=for-the-badge&logo=swift&logoColor=white" alt="Swift"></a>
  <a href="https://github.com/niyongsheng/moler"><img src="https://img.shields.io/badge/macOS-14.0+-005a9e?style=for-the-badge&logo=apple&logoColor=white" alt="macOS"></a>
  <a href="/LICENSE"><img src="https://img.shields.io/github/license/niyongsheng/moler?style=for-the-badge" alt="License"></a>
</p>

---

https://github.com/user-attachments/assets/61b2a73d-c8e4-4142-abf6-7effedb59791

## 功能

| 模块 | 图标 | 说明 |
|------|------|------|
| **概览** | 📊 | 系统健康评分、CPU / 内存 / 网络 / 磁盘指标、工具统计 |
| **系统清理** | 🧹 | 深度扫描目录，查看结果并释放磁盘空间 |
| **项目清理** | 🗑️ | 清除过期的 Xcode、Gradle、CocoaPods 等构建残留 |
| **系统优化** | 🔄 | 刷新系统缓存与服务，支持**预演模式** |
| **磁盘分析** | 🎛 | 磁盘占用矩形树图 — 显示所有项目，**按文件类型着色** |
| **软件管理** | 📦 | 扫描并卸载应用，显示体积信息 |

## 安装

```bash
# 通过 Homebrew 安装
brew install --cask niyongsheng/moler/moler

# 移除隔离属性
sudo xattr -rd com.apple.quarantine /Applications/Moler.app
```

> [!IMPORTANT]  
> 需要单独安装来自 [Mole](https://github.com/tw93/Mole) 的 `mo` 命令行工具：`brew install mole`

## 许可证

MIT © 2026 [Nico](https://github.com/niyongsheng)

# ichatAI

iChatAI 是一款基于 SwiftUI 开发的 iOS AI 聚合客户端，将多个主流 AI 网页服务集中到一个应用中，支持快速切换、文件管理、主题设置以及 WebKit 缓存和调试日志管理。

## 功能特性

### AI 服务聚合

- 聚合豆包、文心一言、通义千问、Kimi、DeepSeek、腾讯元宝、ChatGPT、Gemini 和 Grok 等 AI 网页服务。
- 支持在首页快速切换 AI 服务。
- 支持添加、删除自定义 AI 服务网址。
- 支持设置默认启动服务。
- 支持控制首页服务切换菜单中显示的服务。

### 网页浏览与下载

- 使用 `WKWebView` 加载 AI 网页端服务。
- 提供网页加载状态提示。
- 支持前进后退手势。
- 支持网页 Blob 数据下载，并保存到 App 沙盒。

### 文件管理

- 自动扫描 App 沙盒中的下载文件。
- 支持图片、文档、视频和其他文件分类。
- 图片使用网格展示，其他文件使用列表展示。
- 支持下拉刷新文件列表。
- 支持 Quick Look 预览文件。
- 支持删除单个文件或清空全部文件。
- 显示文件数量、类型、大小和创建时间。

### 设置与个性化

- 支持跟随系统、浅色模式和深色模式。
- 支持配置默认 AI 服务和自定义 AI 服务。
- 显示 App 版本信息。

### 日志管理

- 记录网页加载、文件下载和错误信息。
- 支持查看当天的调试日志。
- 支持日志自动滚动、复制、刷新和清空。
- 日志文件达到 10 MB 时自动轮转。
- 自动清理超过 7 天的日志文件。

### 存储管理

- 统计 WebKit 缓存和网站数据占用。
- 使用饼图展示不同缓存类型的存储占比。
- 支持查看磁盘缓存、Cookie、本地存储和 IndexedDB 等数据。
- 支持选择并清理指定类型的缓存。
- 显示 App 总存储占用。

## 项目结构

```text
ichatAI/
├── ichatAIApp.swift                 # App 入口
├── ContentView.swift                # 主界面与 Tab 导航
├── Assets.xcassets/                 # 图片、颜色与 App 图标资源
│
├── Models/
│   └── DownloadedFile.swift          # 下载文件模型与文件类型定义
│
├── Service/
│   ├── AIService.swift               # AI 服务模型与服务管理器
│   ├── FileManager.swift             # 下载文件扫描、分类与删除
│   └── LogManager.swift              # 日志记录、轮转与清理
│
├── Utils/
│   ├── AppInfo.swift                 # App 版本信息
│   └── WebCacheManager.swift         # WebKit 缓存统计与清理
│
└── Views/
	├── HomeView.swift                # AI 服务主页
	├── AIWebView.swift               # WKWebView 网页容器
	├── FilesTabView.swift            # 文件管理页面
	├── AIServiceManageView.swift     # AI 服务管理页面
	├── SettingsView.swift            # 设置页面
	├── LogViewerView.swift           # 调试日志查看器
	├── StorageManagerView.swift      # 存储管理页面
	│
	└── Components/
		└── FileThumbnailView.swift   # 文件缩略图组件
```

## 技术栈

- Swift
- SwiftUI
- WebKit
- QuickLook
- Swift Charts
- Combine
- UserDefaults
- iOS App Sandbox

## 项目特点

- 无需分别集成多个 AI SDK，通过网页端统一访问不同 AI 服务。
- 支持扩展自定义 AI 网站。
- 下载文件和日志均保存在本地 App 沙盒中。
- 提供文件、缓存和日志管理能力。
- 使用 SwiftUI 构建原生 iOS 用户界面。


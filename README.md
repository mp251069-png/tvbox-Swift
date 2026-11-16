# TVBox-Swift

![Platform iOS | macOS](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-blue.svg)
![Swift Version](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Xcode Version](https://img.shields.io/badge/Xcode-15.0+-blue.svg)

**TVBox-Swift** 是一套基于原生 Swift & SwiftUI 构建的跨平台多媒体应用核心工程。它同时支持 macOS 和 iOS 设备，致力于在双端提供无缝、现代且极其流畅的视听体验。

## ✨ 核心特性

- 🎯 **真正的原生跨平台 (Native Cross-platform)**
  - 基于最新的 SwiftUI 和 SwiftData，一套代码覆盖 macOS (14.0+) 与 iOS (17.0+)。
  - 高度针对多端设备的特定交互形式进行原生级适配与优化。
- 🎨 **前沿的 UI 视觉 (Modern UI & Glassmorphism)**
  - 全新的毛玻璃 (Glassmorphism) 视觉设计体系。
  - 精美流畅的重构动画与微交互，从列表到播放页全系更新。
  - 原生级体验的暗黑模式 (Dark Mode) 全方位支持。
- 🧩 **全方位的媒体功能栈 (Media Stack)**
  - **点播中心 (VOD Center):** 整合了智能资源检索、卡片化视觉呈现与多级详情页。
    - *生态支持:* 原生支持解析主流的 CMS JSON/XML 数据源接口 (`type=0`, `type=1`)。
    - *暂不支持:* 由于 iOS/macOS 平台原生限制与环境安全，内核未集成基于 Java 引擎或 Rhino 逻辑层，**不支持** `type=3` (Spider / Jar) 等依赖动态脚本执行的复杂爬虫源。
  - **直播支持 (Live):** 稳定的流媒体播放基础构件支持。
  - **内容枢纽 (Content Hub):** 便捷的搜索、智能历史记录流、一键收藏管理。
- ⚙️ **健壮的业务底层 (Robust Foundation)**
  - **持久化:** 基于苹果全新 `SwiftData` 技术的现代化缓存与本地数据存储模块。
  - **数据层:** 兼容性极强的网络接口解析引擎，支持非标准的 JSON/XML 接口容错处理与数据清洗。

## 🛠 技术栈

* **语言**: Swift 5.9
* **UI 框架**: SwiftUI
* **数据持久化**: SwiftData
* **工程化管理**: XcodeGen (>= 2.35)

---

## 🔍 与安卓参考版差异

以下差异基于当前仓库代码：

1. **源类型支持范围不同**
   - Swift 版支持 `type=0/1/4`（XML/JSON/Remote）。
   - `type=4` 现在包含 `play=<剧集标识>&flag=<线路>` 的 Remote playerContent 请求，只有解析响应返回直接 HTTP(S) 媒体 URL 后才启动播放器；快速切集会取消旧请求。
   - XML 列表兼容普通文本/CDATA、非纯数字 ID 与常见 XML 实体；播放清单保留 URL 中的 `$`，空线路名不再导致线路错位。
   - Swift 版仍不支持 `type=3 (JAR/Spider)`，也不执行 `csp_` Java 类、QuickJS/Python 插件、Android API 或本地 Spider 代理。这不是完整 TVBox 兼容实现。
2. **配置兼容能力不同**
   - 安卓版支持加密配置解密、`clan://`、相对路径修复、独立直播配置加载等。
   - Swift 版当前为常规 URL 拉取 + 注释容错解析。
3. **解析链路能力不同**
   - 安卓版支持嗅探/解析切换、规则引擎与相关过滤策略。
   - Swift 版的 `parses` 仍仅加载配置，不执行通用 JSON 解析器、WebView 嗅探或解密规则。Remote 响应要求 `parse/jx` 解析器、返回非 HTTP(S) 标识或带非空 `header` 时，会显示明确错误，避免把不完整结果当作可播放地址。
   - `AVPlayer` / `VLCKit` 是媒体播放引擎，不等同于 Spider 执行器；是否能播放仍取决于实际媒体、编码、鉴权和网络。
4. **播放器能力不同**
   - 安卓版支持系统/IJK/EXO/外部播放器等多模式。
   - Swift 版当前支持系统 `AVPlayer` 与 `VLCKit`（iOS/macOS）双引擎切换，IJK/EXO/外部播放器仍未接入。
5. **字幕体系不同**
   - 安卓版支持字幕搜索、本地字幕、样式/延迟调节、内嵌轨道等。
   - Swift 版当前尚未接入完整字幕功能。
6. **直播高级能力不同**
   - 安卓版支持 EPG、回看/时移、分组密码、直播设置分组等。
   - Swift 版当前已支持基础直播分组与线路切换，EPG 仍为简化实现。
7. **筛选与检索形态不同**
   - 安卓版具备分类筛选、快速搜索、复选搜索等界面与交互。
   - Swift 版当前为基础搜索与分类浏览。
8. **远程控制与推送不同**
   - 安卓版具备本地控制服务与推送/遥控相关能力。
   - Swift 版当前未提供该能力。
9. **设置项覆盖度不同**
   - 安卓版设置项更细（DoH、渲染/缩放、历史条数、M3U8 净化、备份恢复等）。
   - Swift 版当前保留核心常用设置。
10. **收藏入口闭环不同**
   - 安卓版详情页支持直接加入/取消收藏。
   - Swift 版目前提供收藏页与收藏数据模型，但详情页收藏入口待完善。

---

## 🚀 快速开始

本项目的主 Xcode 工程文件并未直接包含在仓库代码中，以保证干净的源码树并降低拉取冲突风险。您需要通过 `XcodeGen` 生成配置文件。

### 1. 环境准备
确保您的设备已安装以下必备组件：
*   **macOS** (最新版本)
*   **Xcode 15.0** 或以上版本
*   **Homebrew** (用于安装命令行工具)

安装工程生成器 `XcodeGen`:
```bash
brew install xcodegen
```

### 2. 生成 Xcode 工程
在终端进入本项目的根目录，执行以下命令以生成 `tvbox.xcodeproj` 文件：
```bash
xcodegen generate
```

### 3. 构建与运行
打开刚刚使用 XcodeGen 生成的 `tvbox.xcodeproj`：
- 选择合适的 Scheme (`tvbox` 对应 iOS, `tvbox-macOS` 对应 macOS)。
- 直接在设备或模拟器真机上 `Command + R` 进行编译与运行调试。

### 源与播放验证

GitHub Actions 的 iOS 工作流运行源解析回归测试，再构建 unsigned Release 应用。测试覆盖 XML/JSON/Remote 详情、多线路清单、Remote playerContent 响应与错误边界，并包含公开 HLS 测试流的 AVPlayer 时间线推进冒烟测试。该网络测试依赖外部流可访问；测试失败不能视为播放成功。模拟器 AVPlayer 的时间线证据也不等于 iPhone 真机画面/声音、所有第三方源或 DRM 内容均已验收。

参考协议：[TVBoxOS 配置类型](https://github.com/q215613905/TVBoxOS/blob/main/README.md)、[Remote 播放请求实现](https://github.com/q215613905/TVBoxOS/blob/main/app/src/main/java/com/github/tvbox/osc/viewmodel/SourceViewModel.java)、[CatVodSpider 运行时与示例](https://github.com/FongMi/CatVodSpider)。

---

### iOS 版本打包

1. 确保已安装通用依赖：
   - Xcode 15+
   - [XcodeGen](https://github.com/yonaskolb/XcodeGen) (可选，用于生成工程)

2. 运行打包脚本：
   ```bash
   chmod +x package_ios.sh
   ./package_ios.sh
   ```

3. **注意**：
   - 脚本默认生成 `.xcarchive` 文件。
   - 如需自动生成 `.ipa`，请在 `ExportOptions.plist` 中填写您的 `teamID`。
   - 您也可以在 Xcode 中打开 `tvbox.xcodeproj`，选择 `tvbox` scheme，然后点击 `Product > Archive` 手动打包。

## 📦 macOS 独立打包

项目已内置自动化打包脚本 `package_mac.sh`。当您需要分发 macOS 版本时，直接运行即可自动清理缓存、构建并生成免安装的 `.dmg` 拖拽式安装包。

```bash
chmod +x package_mac.sh
./package_mac.sh
```

> **成功输出提示:** `✅ 打包完成！生成文件: TVBox-macOS.dmg`

---

## 📂 简明目录结构

```text
├── tvbox
│   ├── Models/         # 数据模型定义
│   ├── ViewModels/     # 业务逻辑与状态管理 (MVVM)
│   ├── Views/          # 所有的 SwiftUI 原生视图组件
│   ├── Services/       # 网络层、配置解析层等外部服务交互
│   ├── Persistence/    # 数据库 (SwiftData) 配置与读写管理
│   ├── Utils/          # 通用的帮助类与扩展函数
│   └── Assets.xcassets # 资源文件集、图标与预设全局色彩 (AccentColor)
├── project.yml         # XcodeGen 的工程模板描述文件
├── package_mac.sh      # macOS DMG 打包脚本
└── process_icon.py     # 图片转换脚本套件
```

---

## 📜 开源协议

本项目采用 [MIT License](./LICENSE) 开源发布。

---

## ⚠️ 开源免责声明 (Disclaimer)

**本项目仅供编程技术交流、学习 Swift 与 SwiftUI 原生应用开发原理之目的。**

1. 开发者不对本项目代码产生的任何直接或间接后果负责。
2. 本项目**不提供、不内置、不分发**任何形式的具体影视资源、播放源配置接口（如接口 URL、JSON 规则等）。
3. 使用本项目所导致的所有合法性与知识产权纠纷（包括但不限于使用者自行导入第三方规则/接口而引发的版权问题），由使用者自行承担全部法律责任。
4. 本应用旨在作为一个本地多媒体客户端工具框架进行技术探讨，任何以此框架衍生的商业化产品与违法行为均与原作者无关。如果您下载、安装、编译或使用了本项目，即代表您理解并完全接受本免责声明之所有条款。

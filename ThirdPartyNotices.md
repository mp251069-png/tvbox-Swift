# 第三方组件与许可

## HGhubX 短剧兼容层

短剧入口参考并移植了 [HGhubX](https://github.com/zxsos/HGhubX) 的公开访客 API 行为、封面解密兼容方式和播放地址回退逻辑，并以 Swift/SwiftUI 原生实现。此模块不包含 HGhubX 的 Tauri、Rust 或 React 应用代码，也不移植登录互动、批量抓取或下载功能。

HGhubX 相关部分依照 **PolyForm Noncommercial License 1.0.0** 提供，仅允许非商业用途。完整许可文本同时保存在本仓库 `ThirdPartyNotices/HGhubX-LICENSE.txt`，并作为资源打包进 iOS/macOS 应用。该许可不替代其他第三方内容提供方的条款。

Required Notice: Copyright (c) 2026 HGhubX contributors (https://github.com/zxsos/HGhubX)

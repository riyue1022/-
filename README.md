# LinkCleaner｜链接净化器

iOS 17+ 原生 SwiftUI App，包含 Share Extension，可从系统分享菜单导入链接。

## 功能
- URL 参数拆解与风险分类
- 通用分享/追踪参数净化
- 小红书 shareRedId、share_id、xsec_token 等字段提示（不将未验证参数认定为 UID）
- Base64 候选解码与标准往返校验
- 标准/严格两种净化模式
- 小红书短链接跳转尝试
- 本地历史记录与分享菜单快速净化

## 构建
仓库 Actions 中的 **Build unsigned IPA** 会使用 macOS Runner 构建未签名 IPA，并上传为 Artifact。
未签名 IPA 不等于可直接安装包。安装前仍需按设备环境完成签名或适用的安装处理。

## 隐私
普通 URL 分析在本机执行。只有主动点击短链接展开时，App 才向短链接源站发起请求。分享链接中的访问令牌可能影响内容访问，净化结果应先检查再公开转发。

## 开发
使用 Xcode 打开 `LinkCleaner.xcodeproj`。Bundle ID 为 `com.rly.linkcleaner`，如需签名请在 Xcode 中选择自己的 Team。

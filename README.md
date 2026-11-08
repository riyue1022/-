# LinkCleaner｜链接净化器

iOS 17+ 原生 SwiftUI App，包含 Share Extension，可从系统分享菜单导入链接。

## 功能
- URL 参数拆解与风险分类
- 通用分享/追踪参数净化
- 标准/严格两种净化模式
- 小红书短链接跳转尝试
- 独立的「分享者 ID 逆向」页面
- 检查 shareRedId、share_red_id、share_uid、user_id、appuid、author_id 等候选字段
- Base64 / URL-safe Base64 / Hex 解码尝试，并展示逐项往返校验结果
- 区分分享者候选字段、分享追踪标识与访问令牌
- 本地历史记录与分享菜单快速净化

## 逆向分析边界
- 解码成功或往返校验通过，只能证明编码规则可复现，不代表解码结果就是小红书 UID / appuid。
- share_id 作为分享/追踪标识单独展示，不直接认定为分享者账号 ID。
- 不猜测未验证的字符偏移或加密算法；只有获得独立样本对应关系后才升级证据等级。
- 不尝试绕过登录、访问控制或获取非公开账号资料。

## 构建
仓库 Actions 中的 **Build LinkCleaner unsigned IPA** 会使用 macOS Runner 构建未签名 IPA，并上传为 Artifact。
未签名 IPA 不等于可直接安装包。安装前仍需按设备环境完成签名或适用的安装处理。

## 隐私
普通 URL 分析在本机执行。只有主动点击短链接展开时，App 才向短链接源站发起请求；展开请求不携带 App 登录 Cookie，但源站仍会收到网络请求。访问令牌在逆向分析页中默认隐藏。

## 开发
使用 Xcode 打开 `LinkCleaner.xcodeproj`。Bundle ID 为 `com.rly.linkcleaner`，如需签名请在 Xcode 中选择自己的 Team。

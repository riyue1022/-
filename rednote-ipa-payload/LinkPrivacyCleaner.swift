import Foundation

struct LinkPrivacyCleanResult {
    let cleanedURL: URL
    let removedParameters: [String]
    let preservedAccessToken: Bool
    let isShortLink: Bool
}

enum LinkPrivacyCleanError: LocalizedError {
    case emptyInput, noURLFound, multipleURLs, invalidURL, unsupportedDomain

    var errorDescription: String? {
        switch self {
        case .emptyInput: return "请先粘贴一条小红书分享链接。"
        case .noURLFound: return "没有识别到链接，请粘贴完整的小红书链接。"
        case .multipleURLs: return "检测到多条链接，请一次只净化一条。"
        case .invalidURL: return "链接格式不正确，无法安全处理。"
        case .unsupportedDomain: return "仅支持小红书官方域名及 xhslink.cn / xhslink.com 短链接。"
        }
    }
}

/// 本地移除已知分享者标识和追踪参数；未知参数默认保留，降低误删可用参数的风险。
enum LinkPrivacyCleaner {
    private static let removableNames: Set<String> = [
        "app_platform", "app_version", "share_from_user_hidden", "xsec_source",
        "author_share", "xhsshare", "shareredid", "share_red_id", "share_id", "shareid",
        "share_uid", "share_user_id", "share_from_user", "share_user", "share_channel",
        "share_time", "share_source", "share_origin", "share_user_name", "share_nickname",
        "share_url", "share", "user_id", "uid", "author_id", "appuid",
        "trace_id", "track_id", "spm"
    ]

    static func clean(_ input: String, preserveAccessToken: Bool = true) throws -> LinkPrivacyCleanResult {
        let normalized = input
            .replacingOccurrences(of: "\\&", with: "&")
            .replacingOccurrences(of: "&amp;", with: "&")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw LinkPrivacyCleanError.emptyInput }

        let urls = extractURLs(from: normalized)
        guard !urls.isEmpty else { throw LinkPrivacyCleanError.noURLFound }
        guard urls.count == 1, let sourceURL = URL(string: urls[0]),
              var components = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false) else {
            throw LinkPrivacyCleanError.multipleURLs
        }

        let host = (components.host ?? "").lowercased()
        guard isSupportedHost(host) else { throw LinkPrivacyCleanError.unsupportedDomain }

        var removed: [String] = []
        let filteredItems = (components.queryItems ?? []).filter { item in
            let key = item.name.lowercased()
            let isAccessToken = key == "xsec_token"
            let shouldRemove = isKnownTrackingParameter(key) || (!preserveAccessToken && isAccessToken)
            if shouldRemove { removed.append(item.name) }
            return !shouldRemove
        }
        components.queryItems = filteredItems.isEmpty ? nil : filteredItems
        guard let cleanedURL = components.url else { throw LinkPrivacyCleanError.invalidURL }

        let keepsToken = filteredItems.contains { $0.name.lowercased() == "xsec_token" }
        let isShort = ["xhslink.cn", "xhslink.com"].contains { host == $0 || host.hasSuffix("." + $0) }
        return LinkPrivacyCleanResult(
            cleanedURL: cleanedURL,
            removedParameters: removed,
            preservedAccessToken: keepsToken,
            isShortLink: isShort
        )
    }

    private static func isKnownTrackingParameter(_ key: String) -> Bool {
        removableNames.contains(key) || key.hasPrefix("utm_")
    }

    private static func isSupportedHost(_ host: String) -> Bool {
        ["xiaohongshu.com", "xhslink.cn", "xhslink.com"].contains {
            host == $0 || host.hasSuffix("." + $0)
        }
    }

    private static func extractURLs(from text: String) -> [String] {
        let pattern = #"https?://[^\s<>\"')\]]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange]).trimmingCharacters(in: CharacterSet(charactersIn: "，。；;）)]"))
        }
    }
}

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

struct LinkCleanerView: View {
    @State private var input = ""
    @State private var result: LinkPrivacyCleanResult?
    @State private var errorMessage: String?
    @State private var preserveAccessToken = true
    @State private var showCopied = false

    private let accent = Color(red: 0.88, green: 0.20, blue: 0.28)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("小红书链接隐私净化")
                        .font(.system(size: 27, weight: .bold))
                    Text("移除分享者标识和常见追踪参数，尽量保留笔记链接的可访问性。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("分享链接").font(.headline)
                        Spacer()
                        Button {
                            if let pasted = UIPasteboard.general.string { input = pasted }
                        } label: {
                            Label("粘贴", systemImage: "doc.on.clipboard")
                        }
                        .font(.subheadline.weight(.medium))
                    }

                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(uiColor: .secondarySystemBackground))
                        if input.isEmpty {
                            Text("粘贴小红书分享链接，例如 xiaohongshu.com 或 xhslink.cn 链接……")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 14)
                        }
                        TextEditor(text: $input)
                            .scrollContentBackground(.hidden)
                            .padding(7)
                            .frame(minHeight: 132)
                            .accessibilityLabel("待净化的小红书链接输入框")
                    }
                    .frame(minHeight: 132)

                    Toggle(isOn: $preserveAccessToken) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("保留 xsec_token 访问参数")
                                .font(.subheadline.weight(.medium))
                            Text("默认保留以尽量维持链接可访问；关闭后隐私清理更彻底，但链接可能打不开。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(accent)

                    Button(action: clean) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("净化链接")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .foregroundStyle(.white)
                        .background(accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)

                    Button("清空") {
                        input = ""
                        result = nil
                        errorMessage = nil
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                if let result {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("净化完成", systemImage: "checkmark.shield.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text("净化后的链接")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(result.cleanedURL.absoluteString)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                        Button {
                            UIPasteboard.general.string = result.cleanedURL.absoluteString
                            showCopied = true
                        } label: {
                            Label("复制净化后的链接", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accent)

                        Link(destination: result.cleanedURL) {
                            Label("打开净化后的链接", systemImage: "arrow.up.right.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.primary)

                        Divider()
                        VStack(alignment: .leading, spacing: 6) {
                            Text("已移除的参数（\(result.removedParameters.count)）")
                                .font(.subheadline.weight(.semibold))
                            if result.removedParameters.isEmpty {
                                Text("没有发现本工具识别的分享者标识或追踪参数。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(result.removedParameters.joined(separator: "、"))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }

                        if result.preservedAccessToken {
                            Label("已保留 xsec_token，尽量保持原笔记可访问。它是访问参数，不等同于分享者 UID。", systemImage: "key.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Label("未保留 xsec_token；链接隐私清理更彻底，但可能无法打开笔记。", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if result.isShortLink {
                            Label("识别到小红书短链接。为避免访问外部地址，本工具不会展开跳转；只清理短链接中可见的参数，跳转目标内的参数无法检查。", systemImage: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("净化规则与隐私")
                        .font(.caption.weight(.semibold))
                    Text("在本机离线处理，不会上传链接或访问小红书。移除 shareRedId 等可用于识别分享者的字段，以及常见分享/追踪参数；未知参数默认保留，降低误删风险。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("链接隐私净化")
        .navigationBarTitleDisplayMode(.inline)
        .alert("已复制", isPresented: $showCopied) {
            Button("好", role: .cancel) { }
        } message: {
            Text("净化后的链接已复制到剪贴板。")
        }
        .tint(accent)
    }

    private func clean() {
        result = nil
        errorMessage = nil
        do {
            result = try LinkPrivacyCleaner.clean(input, preserveAccessToken: preserveAccessToken)
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? "净化失败，请检查链接。"
        } catch {
            errorMessage = "净化失败：\(error.localizedDescription)"
        }
    }
}
#endif

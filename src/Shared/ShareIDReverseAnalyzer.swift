import Foundation

enum ShareIDFindingKind: String {
    case publisherCandidate = "分享者 ID 候选"
    case shareReference = "分享/追踪标识"
    case accessToken = "访问令牌"
}

struct ShareIDDecodeAttempt: Identifiable {
    let id = UUID()
    let method: String
    let output: String
    let roundTripVerified: Bool
    let detail: String
}

struct ShareIDFinding: Identifiable {
    let id = UUID()
    let field: String
    let rawValue: String
    let kind: ShareIDFindingKind
    let explanation: String
    let decodeAttempts: [ShareIDDecodeAttempt]

    var displayValue: String {
        guard kind == .accessToken else { return rawValue }
        if rawValue.count <= 8 { return String(repeating: "•", count: rawValue.count) }
        return "\(rawValue.prefix(4))••••\(rawValue.suffix(4))"
    }

    var evidenceLabel: String {
        switch kind {
        case .publisherCandidate: return "未验证"
        case .shareReference: return "不能据此认定为 UID"
        case .accessToken: return "敏感令牌 · 已隐藏"
        }
    }
}

struct ShareIDAnalysis {
    let original: String
    let normalizedURL: String
    let host: String
    let isXiaohongshu: Bool
    let findings: [ShareIDFinding]
    let steps: [String]

    var publisherCandidateCount: Int {
        findings.filter { $0.kind == .publisherCandidate }.count
    }
}

enum XHSShareReverseAnalyzer {
    private static let publisherKeys: Set<String> = [
        "shareredid", "share_red_id", "share_uid", "share_user_id",
        "uid", "user_id", "userid", "appuid", "author_id", "authorid",
        "owner_id", "ownerid"
    ]

    private static let shareReferenceKeys: Set<String> = [
        "share_id", "tracking_id", "track_id"
    ]

    private static let tokenKeys: Set<String> = [
        "xsec_token", "access_token", "auth_token", "authorization", "token"
    ]

    static func analyze(_ input: String) -> ShareIDAnalysis? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let candidate = URLCleaner.extractURL(from: raw) ?? raw
        let normalizedInput = candidate.contains("://") ? candidate : "https://\(candidate)"
        guard let components = URLComponents(string: normalizedInput),
              let host = components.host, !host.isEmpty else { return nil }

        let isXHS = host.lowercased().contains("xiaohongshu") ||
            host.lowercased() == "xhslink.cn" ||
            host.lowercased() == "www.xhslink.cn" ||
            host.lowercased() == "xhslink.com" ||
            host.lowercased() == "www.xhslink.com"

        var findings: [ShareIDFinding] = []
        var steps = [
            "从输入文本中提取 URL，并解析主机名与查询参数。",
            "只检查链接中实际出现的字段；不根据参数名称直接认定账号身份。",
            "对疑似编码值尝试标准 Base64 / URL-safe Base64 与十六进制解析。",
            "往返校验只证明编码可复现，不证明解码结果就是 UID / appuid。"
        ]

        for item in components.queryItems ?? [] {
            let key = item.name.lowercased()
            let value = item.value ?? ""

            if publisherKeys.contains(key) {
                let explanation: String
                if key == "shareredid" || key == "share_red_id" {
                    explanation = "这是优先检查的分享者线索字段。但目前仅凭字段名及解码结果，不能确认它等于小红书 UID / appuid。需要跨账号样本及独立主页或可信接口对应关系验证。"
                } else {
                    explanation = "字段名称看起来可能与用户/作者有关；当前只将它列为候选值，尚未独立验证其是否为分享者账号 UID。"
                }
                findings.append(
                    ShareIDFinding(
                        field: item.name,
                        rawValue: value,
                        kind: .publisherCandidate,
                        explanation: explanation,
                        decodeAttempts: decodeCandidates(value)
                    )
                )
            } else if shareReferenceKeys.contains(key) {
                findings.append(
                    ShareIDFinding(
                        field: item.name,
                        rawValue: value,
                        kind: .shareReference,
                        explanation: "这类值更适合作为分享事件或追踪标识看待，不能仅凭它反推出分享者账号 UID。",
                        decodeAttempts: decodeCandidates(value)
                    )
                )
            } else if tokenKeys.contains(key) {
                findings.append(
                    ShareIDFinding(
                        field: item.name,
                        rawValue: value,
                        kind: .accessToken,
                        explanation: "疑似访问令牌或访问凭据，不是分享者身份 ID。界面会隐藏原值，也不会尝试解码或复制它。",
                        decodeAttempts: []
                    )
                )
            }
        }

        if !isXHS {
            steps.append("当前域名不是已识别的小红书域名；字段名称仅按通用候选规则展示。")
        }
        if findings.isEmpty {
            steps.append("未发现内置规则关注的分享者候选字段、分享追踪字段或访问令牌。")
        } else if findings.allSatisfy({ $0.kind != .publisherCandidate }) {
            steps.append("找到的只有分享追踪标识或访问令牌，没有可列为分享者 ID 候选的字段。")
        }
        if findings.contains(where: { $0.kind == .publisherCandidate && $0.decodeAttempts.contains(where: \.roundTripVerified) }) {
            steps.append("至少一个候选值通过编码往返校验；这仍然不是 UID 身份验证。")
        }
        if (components.queryItems ?? []).isEmpty {
            steps.append("当前 URL 没有可见查询参数。若输入是 xhslink.cn 短链接，先展开短链再分析。")
        }

        return ShareIDAnalysis(
            original: raw,
            normalizedURL: components.url?.absoluteString ?? normalizedInput,
            host: host,
            isXiaohongshu: isXHS,
            findings: findings,
            steps: steps
        )
    }

    private static func decodeCandidates(_ value: String) -> [ShareIDDecodeAttempt] {
        guard value.count >= 8 else { return [] }
        var attempts: [ShareIDDecodeAttempt] = []

        let base64Alphabet = #"^[A-Za-z0-9+/_=-]+$"#
        if value.range(of: base64Alphabet, options: .regularExpression) != nil {
            let isURLSafe = value.contains("-") || value.contains("_")
            let normalized = value
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            let padding = (4 - normalized.count % 4) % 4
            let padded = normalized + String(repeating: "=", count: padding)

            if let data = Data(base64Encoded: padded, options: []) {
                let canonical = data.base64EncodedString()
                let expected = isURLSafe
                    ? canonical.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
                    : canonical
                let lhs = value.replacingOccurrences(of: "=+$", with: "", options: .regularExpression)
                let rhs = expected.replacingOccurrences(of: "=+$", with: "", options: .regularExpression)
                let roundTrip = lhs == rhs

                if let text = String(data: data, encoding: .utf8) {
                    let printable = text.unicodeScalars.filter {
                        !CharacterSet.controlCharacters.contains($0)
                    }.count
                    let ratio = Double(printable) / Double(max(text.unicodeScalars.count, 1))
                    if ratio >= 0.85 {
                        attempts.append(
                            ShareIDDecodeAttempt(
                                method: isURLSafe ? "URL-safe Base64 → UTF-8" : "标准 Base64 → UTF-8",
                                output: text,
                                roundTripVerified: roundTrip,
                                detail: roundTrip ? "按同一 Base64 规则重新编码后与原值一致；仅证明编码可逆。" : "解码得到可打印文本，但标准化后未能与原值完全往返匹配。"
                            )
                        )
                    } else {
                        attempts.append(
                            ShareIDDecodeAttempt(
                                method: isURLSafe ? "URL-safe Base64 → 原始字节" : "标准 Base64 → 原始字节",
                                output: data.map { String(format: "%02x", $0) }.joined(),
                                roundTripVerified: roundTrip,
                                detail: "结果不是可读 UTF-8 文本，按字节展示；不强行解释为账号 ID。"
                            )
                        )
                    }
                } else {
                    attempts.append(
                        ShareIDDecodeAttempt(
                            method: "Base64 → 原始字节",
                            output: data.map { String(format: "%02x", $0) }.joined(),
                            roundTripVerified: roundTrip,
                            detail: "解码结果不是 UTF-8 文本，按十六进制字节展示。"
                        )
                    )
                }
            }
        }

        let hexPattern = #"^[0-9A-Fa-f]{16,}$"#
        if value.count % 2 == 0,
           value.range(of: hexPattern, options: .regularExpression) != nil {
            let bytes = stride(from: 0, to: value.count, by: 2).compactMap { offset -> UInt8? in
                let start = value.index(value.startIndex, offsetBy: offset)
                let end = value.index(start, offsetBy: 2)
                return UInt8(value[start..<end], radix: 16)
            }
            if bytes.count * 2 == value.count {
                let data = Data(bytes)
                let output: String
                let detail: String
                if let text = String(data: data, encoding: .utf8),
                   text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
                    output = text
                    detail = "十六进制字节可转成 UTF-8 文本；不能据此认定为 UID。"
                } else {
                    output = bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
                    detail = "按十六进制字节拆分；仅凭长度或字符集不能判断它是 ObjectId 或 UID。"
                }
                attempts.append(
                    ShareIDDecodeAttempt(
                        method: "Hex → 字节",
                        output: output,
                        roundTripVerified: true,
                        detail: detail
                    )
                )
            }
        }

        return attempts
    }
}

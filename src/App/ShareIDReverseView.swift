struct ShareIDReverseView: View {
    @State private var input = ""
    @State private var analysis: ShareIDAnalysis?
    @State private var isResolving = false
    @State private var alertMessage = ""
    @State private var showingAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                introduction
                inputCard
                actionButtons

                if let analysis {
                    resultPanel(analysis)
                } else {
                    Label("粘贴小红书分享链接，提取分享者 ID 候选字段。", systemImage: "person.crop.circle.badge.magnifyingglass")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("分享者 ID 逆向")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("清空") {
                    input = ""
                    analysis = nil
                }
            }
        }
        .alert("分享者 ID 逆向", isPresented: $showingAlert) {
            Button("好", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("分享者 ID 逆向分析")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("检查 shareRedId、user_id、appuid 等字段，展示可复现的解码过程和证据等级。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("分享链接")
                    .font(.headline)
                Spacer()
                Button {
                    if let pasted = UIPasteboard.general.string {
                        input = pasted
                        analyze()
                    } else {
                        showAlert("剪贴板里没有文本")
                    }
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                        .font(.subheadline.weight(.semibold))
                }
            }
            TextEditor(text: $input)
                .frame(minHeight: 112)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if input.isEmpty {
                        Text("粘贴 xhslink.cn 或小红书完整分享链接…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 17)
                            .allowsHitTesting(false)
                    }
                }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: analyze) {
                Label("开始逆向分析", systemImage: "waveform.path.ecg")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Button {
                Task { await expandShortLink() }
            } label: {
                if isResolving {
                    ProgressView("正在展开短链接…")
                        .frame(maxWidth: .infinity)
                } else {
                    Label("展开小红书短链接后分析", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isResolving || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .font(.subheadline.weight(.semibold))
    }

    private func resultPanel(_ analysis: ShareIDAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("逆向结果")
                    .font(.headline)
                Spacer()
                Text(analysis.isXiaohongshu ? "小红书链接" : "其他域名")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(analysis.isXiaohongshu ? .red : .secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("解析域名")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(analysis.host)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }

            HStack(spacing: 8) {
                summaryMetric(title: "分享者候选", value: "\(analysis.publisherCandidateCount)", icon: "person")
                summaryMetric(title: "线索字段", value: "\(analysis.findings.count)", icon: "list.bullet")
            }

            if analysis.findings.isEmpty {
                Label("没有找到已知的分享者候选字段。请确认是否已展开短链接，并尝试提供完整跳转 URL。", systemImage: "exclamationmark.magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(analysis.findings) { finding in
                    findingCard(finding)
                }
            }

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("逆向步骤与证据")
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(analysis.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 19, height: 19)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground))
                            .clipShape(Circle())
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Button {
                let lines = analysis.findings
                    .filter { $0.kind != .accessToken }
                    .map { "\($0.field)=\($0.rawValue)" }
                guard !lines.isEmpty else {
                    showAlert("没有可复制的候选字段")
                    return
                }
                UIPasteboard.general.string = lines.joined(separator: "\n")
                showAlert("已复制候选字段（已排除访问令牌）")
            } label: {
                Label("复制候选字段", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func findingCard(_ finding: ShareIDFinding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(finding.field)
                    .font(.caption.monospaced().weight(.semibold))
                Spacer(minLength: 8)
                Text(finding.evidenceLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(finding.kind == .publisherCandidate ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(Capsule())
            }
            Text(finding.displayValue.isEmpty ? "（空值）" : finding.displayValue)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Text(finding.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(finding.decodeAttempts) { attempt in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(attempt.method)
                            .font(.caption2.weight(.semibold))
                        Spacer()
                        Text(attempt.roundTripVerified ? "往返通过" : "未通过")
                            .font(.caption2)
                            .foregroundStyle(attempt.roundTripVerified ? .green : .secondary)
                    }
                    Text(attempt.output)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                    Text(attempt.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            if finding.kind == .publisherCandidate && finding.decodeAttempts.isEmpty {
                Text("未得到可复现的 Base64 / Hex 解码结果。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func summaryMetric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func analyze() {
        guard let value = XHSShareReverseAnalyzer.analyze(input) else {
            showAlert("无法识别链接。请检查 URL 是否完整，并包含域名。")
            return
        }
        analysis = value
    }

    @MainActor
    private func expandShortLink() async {
        isResolving = true
        defer { isResolving = false }
        do {
            let expanded = try await ShortLinkResolver.resolve(input)
            input = expanded
            analyze()
        } catch {
            showAlert(error.localizedDescription)
        }
    }

    private func showAlert(_ message: String) {
        alertMessage = message
        showingAlert = true
    }
}

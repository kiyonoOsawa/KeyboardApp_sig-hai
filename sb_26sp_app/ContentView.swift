//
//  ContentView.swift
//  sb_26sp_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SentenceInputLog.timestamp, order: .reverse) private var sentenceLogs: [SentenceInputLog]
    @Query(sort: \KeyInputLog.timestamp, order: .reverse) private var keyLogs: [KeyInputLog]

    @State private var showKeyLogs = false
    @State private var isAnalyzingPending = false
    @State private var analyzerReady = false
    @State private var analyzerMessage = "モデル確認中…"

    var body: some View {
        NavigationStack {
//            Group {
                if sentenceLogs.isEmpty && keyLogs.isEmpty {
                    ContentUnavailableView(
                        "ログがありません",
                        systemImage: "keyboard",
                        description: Text("キーボードで入力し決定すると、一文の保存と同時にネガポジ診断が行われます。")
                    )
                } else {
                    List {
                        Section {
                            Label(
                                analyzerReady ? "端末内モデル: 利用可能" : analyzerMessage,
                                systemImage: analyzerReady ? "checkmark.circle.fill" : "exclamationmark.triangle"
                            )
                            .font(.caption)
                            .foregroundColor(analyzerReady ? .secondary : .orange)

                            Button {
                                Task { await analyzePendingSentences() }
                            } label: {
                                if isAnalyzingPending {
                                    ProgressView()
                                } else {
                                    Text("未分析の一文を端末内で分析")
                                }
                            }
                            .disabled(isAnalyzingPending || !analyzerReady)
                        } header: {
                            Text("感情分析（オンデバイス）")
                        } footer: {
                            Text("決定キーで一文が保存される瞬間に端末内で診断します。未分析分の再実行用ボタンです。")
                        }

                        if !sentenceLogs.isEmpty {
                            Section("一文ログ（感情極性）") {
                                ForEach(sentenceLogs, id: \.id) { log in
                                    SentenceLogRowView(log: log)
                                }
                                .onDelete { offsets in
                                    deleteSentenceLogs(at: offsets)
                                }
                            }
                        }

                        if showKeyLogs, !keyLogs.isEmpty {
                            Section("キーごとのログ") {
                                ForEach(keyLogs, id: \.id) { log in
                                    KeyLogRowView(log: log)
                                }
                                .onDelete { offsets in
                                    deleteKeyLogs(at: offsets)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("入力ログ")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !keyLogs.isEmpty {
                        Button(showKeyLogs ? "キー詳細を隠す" : "キー詳細を表示") {
                            showKeyLogs.toggle()
                        }
                    }
                }
                if !sentenceLogs.isEmpty || !keyLogs.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("全削除", role: .destructive) {
                            deleteAllLogs()
                        }
                    }
                }
            }
            .task {
                InputLogStore.shared.configure()
                await refreshAnalyzerStatus()
                await analyzePendingSentences()
//            }
        }
    }

    private func refreshAnalyzerStatus() async {
        let ready = await OnDeviceSentimentAnalyzer.shared.isReady
        analyzerReady = ready
        analyzerMessage = await OnDeviceSentimentAnalyzer.shared.diagnosticMessage
    }

    private func analyzePendingSentences() async {
        guard await OnDeviceSentimentAnalyzer.shared.isReady else {
            await refreshAnalyzerStatus()
            return
        }
        isAnalyzingPending = true
        defer { isAnalyzingPending = false }

        let pending = sentenceLogs.filter { $0.sentimentScore == nil || $0.sentimentIsLive == true }
        for log in pending {
            do {
                let result = try await OnDeviceSentimentAnalyzer.shared.analyze(text: log.text)
                log.sentimentScore = result.score
                log.sentimentLabel = result.label
                log.sentimentIsLive = false
                print(result.consoleDescription)
            } catch {
                print("[SentimentLog] 分析失敗: \(error.localizedDescription)")
            }
        }
        try? modelContext.save()
    }

    private func deleteSentenceLogs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sentenceLogs[index])
        }
    }

    private func deleteKeyLogs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(keyLogs[index])
        }
    }

    private func deleteAllLogs() {
        for log in sentenceLogs {
            modelContext.delete(log)
        }
        for log in keyLogs {
            modelContext.delete(log)
        }
    }
}

private struct SentenceLogRowView: View {
    let log: SentenceInputLog

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(log.text)
                .font(.body)

            if let score = log.sentimentScore, let label = log.sentimentLabel {
                SentimentBarView(score: score, label: label)
                if log.sentimentIsLive == true {
                    Text("キーボード上の推定")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("感情極性: 未分析")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("開始: \(log.startedAt, style: .time)")
                Spacer()
                Text("確定: \(log.timestamp, style: .time)")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private struct SentimentBarView: View {
    let score: Double
    let label: String

    private var normalized: CGFloat {
        CGFloat((score + 2) / 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("感情極性: \(String(format: "%+.2f", score)) (\(label))")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(scoreColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    Rectangle()
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 1, height: 14)
                        .offset(x: geo.size.width * 0.5 - 0.5)

                    Circle()
                        .fill(scoreColor)
                        .frame(width: 12, height: 12)
                        .offset(x: max(0, min(geo.size.width - 12, geo.size.width * normalized - 6)))
                }
            }
            .frame(height: 14)

            HStack {
                Text("-2")
                Spacer()
                Text("0")
                Spacer()
                Text("+2")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private var scoreColor: Color {
        if score <= -0.5 { return .blue }
        if score >= 0.5 { return .orange }
        return .secondary
    }
}

private struct KeyLogRowView: View {
    let log: KeyInputLog

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(log.keyLabel)
                    .font(.headline)
                Text(directionLabel)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
                Text(log.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                Text("出力:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(outputLabel)
                    .font(.subheadline.monospaced())
            }

            Text("操作: \(actionLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var directionLabel: String {
        switch log.flickDirection {
        case "center": return "タップ"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        default: return log.flickDirection
        }
    }

    private var outputLabel: String {
        if log.outputText.isEmpty {
            switch log.actionType {
            case "delete": return "（削除）"
            case "nextKeyboard": return "（キーボード切替）"
            case "return": return "（改行）"
            default: return "（なし）"
            }
        }
        if log.outputText == " " { return "（空白）" }
        if log.outputText == "\n" { return "（改行）" }
        return log.outputText
    }

    private var actionLabel: String {
        switch log.actionType {
        case "character": return "文字入力"
        case "delete": return "削除"
        case "space": return "空白"
        case "return": return "決定"
        case "nextKeyboard": return "キーボード切替"
        case "voicing": return "濁点・破裂音・小文字"
        default: return log.actionType
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(SharedModelContainer.shared)
}

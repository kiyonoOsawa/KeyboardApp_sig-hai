//
//  InputLogStore.swift
//  sb_26sp_app
//

import Foundation
import SwiftData
import os

@MainActor
final class InputLogStore {
    static let shared = InputLogStore()

    private let logger = Logger(subsystem: "com.kiyono.sb-26sp-app", category: "KeyInput")
    private var container: ModelContainer?
    private var isAvailable = false

    private init() {}

    func configure() {
        guard container == nil else { return }
        do {
            container = try SharedModelContainer.makeContainer()
            isAvailable = true
        } catch {
            isAvailable = false
            logger.error("SwiftDataの初期化に失敗: \(error.localizedDescription)")
        }
    }

    var canLog: Bool {
        isAvailable && container != nil
    }

    func log(_ event: KeyPressEvent) {
        logToConsole(event)

        guard let container else { return }
        let snapshot = event
        DispatchQueue.main.async {
            let context = ModelContext(container)
            let entry = KeyInputLog(
                keyLabel: snapshot.keyLabel,
                flickDirection: snapshot.flickDirection,
                outputText: snapshot.outputText,
                actionType: snapshot.actionType.rawValue,
                documentContextBefore: snapshot.documentContextBefore
            )
            context.insert(entry)
            try? context.save()
        }
    }

    /// 一文を先に保存し、続けてネガポジ診断してスコアを付与する。
    /// （分析を待ってから保存すると、キーボードでモデル読み込み失敗時に文自体が消える）
    func logSentence(text: String, startedAt: Date) {
        let message = "[SentenceLog] \(text)"
        print(message)
        logger.info("\(message)")

        guard let container else {
            print("[SentenceLog] 保存失敗: SwiftData 未初期化（フルアクセスを確認）")
            logger.error("Sentence save skipped: container is nil")
            return
        }

        let context = ModelContext(container)
        let entry = SentenceInputLog(text: text, startedAt: startedAt)
        context.insert(entry)
        do {
            try context.save()
            print("[SentenceLog] 保存完了")
        } catch {
            print("[SentenceLog] 保存エラー: \(error.localizedDescription)")
            logger.error("Sentence save error: \(error.localizedDescription)")
            return
        }

        let entryID = entry.id
        Task { @MainActor in
            await analyzeAndAttachSentiment(text: text, entryID: entryID)
        }
    }

    func updateSentenceSentiment(id: UUID, score: Double, label: String) {
        guard let container else { return }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SentenceInputLog>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let entry = try? context.fetch(descriptor).first else { return }
        entry.sentimentScore = score
        entry.sentimentLabel = label
        try? context.save()
    }

    func analyzeAndAttachSentiment(text: String, entryID: UUID) async {
        do {
            let result = try await OnDeviceSentimentAnalyzer.shared.analyze(text: text)
            print(result.consoleDescription)
            logger.info("\(result.consoleDescription)")
            updateSentenceSentiment(id: entryID, score: result.score, label: result.label)
            print("[SentimentLog] スコア付与完了")
        } catch {
            let fail = "[SentimentLog] 分析失敗（文は保存済み）: \(error.localizedDescription)"
            print(fail)
            logger.error("\(fail)")
        }
    }

    private func logToConsole(_ event: KeyPressEvent) {
        let message = event.consoleDescription
        print(message)
        logger.info("\(message)")
    }

    func deleteAll() {
        guard let container else { return }
        let context = ModelContext(container)
        if let keyLogs = try? context.fetch(FetchDescriptor<KeyInputLog>()) {
            for log in keyLogs { context.delete(log) }
        }
        if let sentenceLogs = try? context.fetch(FetchDescriptor<SentenceInputLog>()) {
            for log in sentenceLogs { context.delete(log) }
        }
        try? context.save()
    }
}

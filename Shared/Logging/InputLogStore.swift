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

    /// キーボードが保存したあとに本体アプリが再読み込みするための印
    static let lastWriteKey = "inputLogLastWriteAt"

    private let logger = Logger(subsystem: "com.kiyono.sb-26sp-app", category: "KeyInput")
    private var container: ModelContainer?
    private var isAvailable = false
    private var lastConfigureError: String?

    private init() {}

    /// 失敗しても次回また試せる。長時間後のキーボード再表示でも呼び直す。
    func configure() {
        if container != nil {
            isAvailable = true
            return
        }
        do {
            container = try SharedModelContainer.makeContainer()
            isAvailable = true
            lastConfigureError = nil
            print("[SentenceLog] SwiftData 初期化完了")
        } catch {
            isAvailable = false
            lastConfigureError = error.localizedDescription
            logger.error("SwiftDataの初期化に失敗: \(error.localizedDescription)")
            print("[SentenceLog] SwiftData 初期化失敗: \(error.localizedDescription)")
        }
    }

    var canLog: Bool {
        isAvailable && container != nil
    }

    var configureErrorMessage: String? {
        lastConfigureError
    }

    func log(_ event: KeyPressEvent) {
        logToConsole(event)

        configure()
        guard let container else {
            print("[KeyLog] 保存スキップ: SwiftData 未初期化（フルアクセスを確認）")
            return
        }
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
            do {
                try context.save()
                Self.markStoreWritten()
            } catch {
                print("[KeyLog] 保存エラー: \(error.localizedDescription)")
                self.logger.error("Key save error: \(error.localizedDescription)")
            }
        }
    }

    /// 一文を先に保存し、続けてネガポジ診断してスコアを付与する。
    /// （分析を待ってから保存すると、キーボードでモデル読み込み失敗時に文自体が消える）
    func logSentence(text: String, startedAt: Date, liveSentiment: SentimentResult? = nil) {
        let message = "[SentenceLog] \(text)"
        print(message)
        logger.info("\(message)")

        configure()
        guard let container else {
            print("[SentenceLog] 保存失敗: SwiftData 未初期化（フルアクセスを確認）")
            logger.error("Sentence save skipped: container is nil")
            return
        }

        let context = ModelContext(container)
        let entry = SentenceInputLog(text: text, startedAt: startedAt)
        if let liveSentiment {
            entry.sentimentScore = liveSentiment.score
            entry.sentimentLabel = liveSentiment.label
            entry.sentimentIsLive = true
        }
        context.insert(entry)
        do {
            try context.save()
            Self.markStoreWritten()
            print("[SentenceLog] 保存完了")
        } catch {
            print("[SentenceLog] 保存エラー: \(error.localizedDescription)")
            logger.error("Sentence save error: \(error.localizedDescription)")
            return
        }

        // 647MB の WRIME はキーボード拡張を落とす。確定後の上書きはメインアプリ側。
        guard !OnDeviceSentimentAnalyzer.isKeyboardExtension else { return }
        let entryID = entry.id
        Task { @MainActor in
            await analyzeAndAttachSentiment(text: text, entryID: entryID)
        }
    }

    func updateSentenceSentiment(id: UUID, score: Double, label: String) {
        configure()
        guard let container else { return }
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<SentenceInputLog>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let entry = try? context.fetch(descriptor).first else { return }
        entry.sentimentScore = score
        entry.sentimentLabel = label
        entry.sentimentIsLive = false
        do {
            try context.save()
            Self.markStoreWritten()
        } catch {
            print("[SentimentLog] スコア保存エラー: \(error.localizedDescription)")
        }
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
        configure()
        guard let container else { return }
        let context = ModelContext(container)
        if let keyLogs = try? context.fetch(FetchDescriptor<KeyInputLog>()) {
            for log in keyLogs { context.delete(log) }
        }
        if let sentenceLogs = try? context.fetch(FetchDescriptor<SentenceInputLog>()) {
            for log in sentenceLogs { context.delete(log) }
        }
        do {
            try context.save()
            Self.markStoreWritten()
        } catch {
            print("[SentenceLog] 全削除エラー: \(error.localizedDescription)")
        }
    }

    /// 本体アプリが App Group 上の最新を読み直すための時刻印
    private static func markStoreWritten() {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        defaults.set(Date().timeIntervalSince1970, forKey: lastWriteKey)
    }

    static var lastWriteAt: TimeInterval {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        return defaults.double(forKey: lastWriteKey)
    }
}

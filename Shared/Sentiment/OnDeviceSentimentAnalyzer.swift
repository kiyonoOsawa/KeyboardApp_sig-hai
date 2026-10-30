//
//  OnDeviceSentimentAnalyzer.swift
//  sb_26sp_app
//
//  Core ML で WRIME 感情極性を端末内推論する。
//  一文保存時（キーボード含む）にすぐ実行する。
//

import Foundation
import CoreML

actor OnDeviceSentimentAnalyzer {
    static let shared = OnDeviceSentimentAnalyzer()

    private var model: MLModel?
    private var tokenizer: HuggingFaceTokenizer?
    private var loadError: Error?
    private(set) var statusDetail: String = "未初期化"

    nonisolated static var isKeyboardExtension: Bool {
        Bundle.main.bundleURL.pathExtension == "appex"
    }

    func analyze(text: String) async throws -> SentimentResult {
        try loadIfNeeded()
        guard let model, let tokenizer else {
            throw loadError ?? SentimentAnalyzerError.modelNotFound
        }

        let encoded = tokenizer.encode(text)
        let inputIds = try Self.multiArray(encoded.inputIds)
        let attention = try Self.multiArray(encoded.attentionMask)

        let provider = try MLDictionaryFeatureProvider(dictionary: [
            "input_ids": MLFeatureValue(multiArray: inputIds),
            "attention_mask": MLFeatureValue(multiArray: attention),
        ])

        let out = try await model.prediction(from: provider)
        let raw = try Self.firstScalar(from: out)
        let score = SentimentResult.denormalize(raw)
        let label = SentimentResult.label(for: score)
        return SentimentResult(text: text, score: score, label: label)
    }

    var isReady: Bool {
        get async {
            do {
                try loadIfNeeded()
                return model != nil && tokenizer != nil
            } catch {
                return false
            }
        }
    }

    var diagnosticMessage: String {
        get async {
            _ = await isReady
            return statusDetail
        }
    }

    private func loadIfNeeded() throws {
        if model != nil, tokenizer != nil { return }
        if let loadError { throw loadError }

        do {
            guard let packageURL = Self.findModelPackage() else {
                statusDetail = "WRIMESentiment.mlpackage が見つかりません。メインアプリを一度ビルド／起動してください。"
                throw SentimentAnalyzerError.modelNotFound
            }
            guard let tokenizerDir = Self.findTokenizerDirectory() else {
                statusDetail = "tokenizer/ が見つかりません。"
                throw SentimentAnalyzerError.modelNotFound
            }

            tokenizer = try HuggingFaceTokenizer(resourceDirectory: tokenizerDir)

            let compiledURL: URL
            if packageURL.pathExtension == "mlpackage" {
                compiledURL = try MLModel.compileModel(at: packageURL)
            } else {
                compiledURL = packageURL
            }

            let config = MLModelConfiguration()
            // キーボードはメモリ制約が厳しいので CPU 優先
            config.computeUnits = Self.isKeyboardExtension ? .cpuOnly : .all
            model = try MLModel(contentsOf: compiledURL, configuration: config)
            statusDetail = "端末内モデル準備完了（保存と同時に分析）"
        } catch {
            loadError = error
            if statusDetail == "未初期化" {
                statusDetail = error.localizedDescription
            }
            throw error
        }
    }

    /// メインアプリ／キーボード（ホストアプリ）／開発パスからモデルを探す
    private static func resourceSearchRoots() -> [URL] {
        var roots: [URL] = []
        if let main = Bundle.main.resourceURL {
            roots.append(main)
        }
        // キーボード拡張 → ホストアプリのリソースを参照
        if isKeyboardExtension {
            let hostApp = Bundle.main.bundleURL
                .deletingLastPathComponent() // PlugIns
                .deletingLastPathComponent() // Xxx.app
            if let hostBundle = Bundle(url: hostApp), let root = hostBundle.resourceURL {
                roots.append(root)
            }
        }
        // App Group にコピーされたモデル（任意）
        if let group = AppGroup.containerURL?.appendingPathComponent("SentimentResources") {
            roots.append(group)
        }
        // 開発時ソースツリー
        roots.append(
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Resources")
        )
        return roots
    }

    private static func findModelPackage() -> URL? {
        let fm = FileManager.default
        let names = ["WRIMESentiment.mlpackage", "WRIMESentiment.mlmodelc"]

        if let url = Bundle.main.url(forResource: "WRIMESentiment", withExtension: "mlpackage")
            ?? Bundle.main.url(forResource: "WRIMESentiment", withExtension: "mlmodelc") {
            return url
        }

        for root in resourceSearchRoots() {
            let direct = [
                root.appendingPathComponent("WRIMESentiment.mlpackage"),
                root.appendingPathComponent("Shared/Sentiment/Resources/WRIMESentiment.mlpackage"),
                root.appendingPathComponent("Sentiment/Resources/WRIMESentiment.mlpackage"),
                root.appendingPathComponent("Resources/WRIMESentiment.mlpackage"),
            ]
            for url in direct where fm.fileExists(atPath: url.path) {
                return url
            }
            if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    if names.contains(url.lastPathComponent) {
                        return url
                    }
                }
            }
        }
        return nil
    }

    private static func findTokenizerDirectory() -> URL? {
        let fm = FileManager.default

        for root in resourceSearchRoots() {
            let candidates = [
                root.appendingPathComponent("tokenizer"),
                root.appendingPathComponent("Shared/Sentiment/Resources/tokenizer"),
                root.appendingPathComponent("Sentiment/Resources/tokenizer"),
                root.appendingPathComponent("Resources/tokenizer"),
            ]
            for url in candidates {
                if fm.fileExists(atPath: url.appendingPathComponent("wrime_meta.json").path)
                    || fm.fileExists(atPath: url.appendingPathComponent("tokenizer.json").path) {
                    return url
                }
            }
            if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    if url.lastPathComponent == "wrime_meta.json" {
                        return url.deletingLastPathComponent()
                    }
                }
            }
        }
        return nil
    }

    private static func multiArray(_ values: [Int32]) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: [1, NSNumber(value: values.count)], dataType: .int32)
        for (i, v) in values.enumerated() {
            array[i] = NSNumber(value: v)
        }
        return array
    }

    private static func firstScalar(from features: MLFeatureProvider) throws -> Double {
        let preferred = ["logits", "var_42", "linear_0", "Identity"]
        for name in preferred {
            if let value = features.featureValue(for: name)?.multiArrayValue {
                return value[0].doubleValue
            }
        }
        for name in features.featureNames {
            if let value = features.featureValue(for: name)?.multiArrayValue {
                return value[0].doubleValue
            }
        }
        throw SentimentAnalyzerError.invalidOutput
    }
}

enum SentimentAnalyzerError: LocalizedError {
    case modelNotFound
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .modelNotFound:
            return "Core MLモデルが見つかりません。export_coreml.py 実行後にメインアプリをビルドしてください。"
        case .invalidOutput:
            return "モデル出力の形式が不正です。"
        }
    }
}

//
//  SentimentResourceInstaller.swift
//  sb_26sp_app
//


import Foundation

enum SentimentResourceInstaller {
    private static let flagKey = "sentimentResourcesCopiedVersion"
    private static let version = "1"

    static func installIfNeeded() {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        if defaults.string(forKey: flagKey) == version,
           let dest = AppGroup.containerURL?.appendingPathComponent("SentimentResources/WRIMESentiment.mlpackage"),
           FileManager.default.fileExists(atPath: dest.path) {
            return
        }

        guard let groupRoot = AppGroup.containerURL?.appendingPathComponent("SentimentResources", isDirectory: true) else {
            return
        }

        let fm = FileManager.default
        try? fm.createDirectory(at: groupRoot, withIntermediateDirectories: true)

        // バンドル内から探す
        let bundleRoots: [URL] = [
            Bundle.main.resourceURL,
            Bundle.main.resourceURL?.appendingPathComponent("Shared/Sentiment/Resources"),
            Bundle.main.resourceURL?.appendingPathComponent("Sentiment/Resources"),
        ].compactMap { $0 }

        var packageSource: URL?
        var tokenizerSource: URL?

        for root in bundleRoots {
            let pkg = root.appendingPathComponent("WRIMESentiment.mlpackage")
            let tok = root.appendingPathComponent("tokenizer")
            if packageSource == nil, fm.fileExists(atPath: pkg.path) {
                packageSource = pkg
            }
            if tokenizerSource == nil, fm.fileExists(atPath: tok.path) {
                tokenizerSource = tok
            }
        }

        // 浅い探索フォールバック
        if packageSource == nil || tokenizerSource == nil,
           let root = Bundle.main.resourceURL,
           let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in enumerator {
                if packageSource == nil, url.lastPathComponent == "WRIMESentiment.mlpackage" {
                    packageSource = url
                }
                if tokenizerSource == nil,
                   url.lastPathComponent == "wrime_meta.json" {
                    tokenizerSource = url.deletingLastPathComponent()
                }
            }
        }

        guard let packageSource, let tokenizerSource else { return }

        let packageDest = groupRoot.appendingPathComponent("WRIMESentiment.mlpackage")
        let tokenizerDest = groupRoot.appendingPathComponent("tokenizer")

        try? fm.removeItem(at: packageDest)
        try? fm.removeItem(at: tokenizerDest)
        do {
            try fm.copyItem(at: packageSource, to: packageDest)
            try fm.copyItem(at: tokenizerSource, to: tokenizerDest)
            defaults.set(version, forKey: flagKey)
            print("[SentimentResources] App Group へコピー完了")
        } catch {
            print("[SentimentResources] コピー失敗: \(error.localizedDescription)")
        }
    }
}

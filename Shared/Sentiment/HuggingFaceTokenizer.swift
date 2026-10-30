//
//  HuggingFaceTokenizer.swift
//  sb_26sp_app
//
//  tokenizer.json (WordPiece / Unigram) を読み、input_ids を生成する。
//

import Foundation

struct TokenizerMeta: Decodable {
    let modelName: String?
    let maxLength: Int
    let tokenizerClass: String?
    let clsTokenId: Int
    let sepTokenId: Int
    let padTokenId: Int
    let unkTokenId: Int

    enum CodingKeys: String, CodingKey {
        case modelName = "model_name"
        case maxLength = "max_length"
        case tokenizerClass = "tokenizer_class"
        case clsTokenId = "cls_token_id"
        case sepTokenId = "sep_token_id"
        case padTokenId = "pad_token_id"
        case unkTokenId = "unk_token_id"
    }
}

final class HuggingFaceTokenizer {
    let maxLength: Int
    let clsTokenId: Int
    let sepTokenId: Int
    let padTokenId: Int
    let unkTokenId: Int

    private let tokenToId: [String: Int]
    private let idToScore: [Int: Double]
    private let kind: Kind
    private let continuingSubwordPrefix: String
    private let unkToken: String

    private enum Kind {
        case wordPiece
        case unigram
    }

    init(resourceDirectory: URL) throws {
        let metaURL = resourceDirectory.appendingPathComponent("wrime_meta.json")
        let tokenizerURL = resourceDirectory.appendingPathComponent("tokenizer.json")

        let meta: TokenizerMeta
        if FileManager.default.fileExists(atPath: metaURL.path) {
            meta = try JSONDecoder().decode(TokenizerMeta.self, from: Data(contentsOf: metaURL))
        } else {
            meta = TokenizerMeta(
                modelName: nil,
                maxLength: 128,
                tokenizerClass: nil,
                clsTokenId: 1,
                sepTokenId: 2,
                padTokenId: 0,
                unkTokenId: 3
            )
        }

        maxLength = meta.maxLength
        clsTokenId = meta.clsTokenId
        sepTokenId = meta.sepTokenId
        padTokenId = meta.padTokenId
        unkTokenId = meta.unkTokenId

        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: tokenizerURL)) as? [String: Any]
        guard let root else { throw TokenizerError.invalidJSON }

        let model = root["model"] as? [String: Any] ?? [:]
        let type = (model["type"] as? String)?.lowercased() ?? "wordpiece"
        continuingSubwordPrefix = (model["continuing_subword_prefix"] as? String) ?? "##"
        unkToken = (model["unk_token"] as? String) ?? "[UNK]"

        var map: [String: Int] = [:]
        var scores: [Int: Double] = [:]

        if let vocabDict = model["vocab"] as? [String: Any] {
            // WordPiece: { "token": id } or Unigram: { "token": score } / [[token, score], ...]
            for (token, value) in vocabDict {
                if let id = value as? Int {
                    map[token] = id
                } else if let id = value as? Double {
                    // sometimes id stored as number
                    map[token] = Int(id)
                }
            }
        }

        if let vocabList = model["vocab"] as? [[Any]] {
            // Unigram list form: [[token, score], ...]
            for (index, item) in vocabList.enumerated() {
                guard let token = item.first as? String else { continue }
                let score = (item.dropFirst().first as? Double) ?? 0
                map[token] = index
                scores[index] = score
            }
            kind = .unigram
        } else if type.contains("unigram") {
            kind = .unigram
            // vocab was dict token->score; assign sequential ids if needed
            if map.isEmpty, let vocabDict = model["vocab"] as? [String: Double] {
                for (index, pair) in vocabDict.sorted(by: { $0.key < $1.key }).enumerated() {
                    map[pair.key] = index
                    scores[index] = pair.value
                }
            } else if let vocabDict = model["vocab"] as? [String: Double] {
                for (token, score) in vocabDict {
                    if let id = map[token] {
                        scores[id] = score
                    } else {
                        // token -> score only
                        let id = map.count
                        map[token] = id
                        scores[id] = score
                    }
                }
            }
        } else {
            kind = .wordPiece
        }

        // added_tokens
        if let added = root["added_tokens"] as? [[String: Any]] {
            for item in added {
                guard let content = item["content"] as? String else { continue }
                if let id = item["id"] as? Int {
                    map[content] = id
                }
            }
        }

        guard !map.isEmpty else { throw TokenizerError.emptyVocab }
        tokenToId = map
        idToScore = scores
    }

    func encode(_ text: String) -> (inputIds: [Int32], attentionMask: [Int32]) {
        let pieces: [String]
        switch kind {
        case .wordPiece:
            pieces = wordPieceTokenize(text)
        case .unigram:
            pieces = unigramTokenize(text)
        }

        var ids: [Int] = [clsTokenId]
        ids.append(contentsOf: pieces.map { tokenToId[$0] ?? unkTokenId })
        ids.append(sepTokenId)

        if ids.count > maxLength {
            ids = Array(ids.prefix(maxLength - 1)) + [sepTokenId]
        }

        var attention = Array(repeating: 1, count: ids.count)
        while ids.count < maxLength {
            ids.append(padTokenId)
            attention.append(0)
        }

        return (ids.map { Int32($0) }, attention.map { Int32($0) })
    }

    // MARK: - WordPiece

    private func wordPieceTokenize(_ text: String) -> [String] {
        let normalized = text.precomposedStringWithCanonicalMapping
        var output: [String] = []
        let tokens = normalized.split { $0.isWhitespace }.map(String.init)
        for token in tokens {
            output.append(contentsOf: wordPiece(token))
        }
        return output
    }

    private func wordPiece(_ token: String) -> [String] {
        if tokenToId[token] != nil { return [token] }
        var subTokens: [String] = []
        var start = token.startIndex
        while start < token.endIndex {
            var end = token.endIndex
            var found: String?
            while start < end {
                var substr = String(token[start..<end])
                if start != token.startIndex {
                    substr = continuingSubwordPrefix + substr
                }
                if tokenToId[substr] != nil {
                    found = substr
                    break
                }
                end = token.index(before: end)
            }
            guard let piece = found else {
                return [unkToken]
            }
            subTokens.append(piece)
            let consumed = piece.hasPrefix(continuingSubwordPrefix)
                ? String(piece.dropFirst(continuingSubwordPrefix.count))
                : piece
            start = token.index(start, offsetBy: consumed.count)
        }
        return subTokens
    }

    // MARK: - Unigram (簡易 Viterbi)

    private func unigramTokenize(_ text: String) -> [String] {
        let normalized = text.precomposedStringWithCanonicalMapping.replacingOccurrences(of: " ", with: "▁")
        // SentencePiece は先頭に ▁ を付けることが多い
        let s = normalized.hasPrefix("▁") ? normalized : "▁" + normalized.replacingOccurrences(of: " ", with: "▁")
        let chars = Array(s)
        let n = chars.count
        if n == 0 { return [] }

        var bestScore = Array(repeating: -Double.infinity, count: n + 1)
        var backPoint = Array(repeating: -1, count: n + 1)
        var backToken = Array(repeating: "", count: n + 1)
        bestScore[0] = 0

        for i in 0..<n {
            if bestScore[i] == -Double.infinity { continue }
            let maxLen = min(16, n - i)
            for len in 1...maxLen {
                let j = i + len
                let piece = String(chars[i..<j])
                guard let id = tokenToId[piece] else { continue }
                let score = idToScore[id] ?? 0
                let candidate = bestScore[i] + score
                if candidate > bestScore[j] {
                    bestScore[j] = candidate
                    backPoint[j] = i
                    backToken[j] = piece
                }
            }
            // unk 1文字フォールバック
            if backPoint[i + 1] == -1 || bestScore[i + 1] == -Double.infinity {
                let piece = String(chars[i])
                let score = idToScore[tokenToId[unkToken] ?? unkTokenId] ?? -10
                let candidate = bestScore[i] + score
                if candidate > bestScore[i + 1] {
                    bestScore[i + 1] = candidate
                    backPoint[i + 1] = i
                    backToken[i + 1] = tokenToId[piece] != nil ? piece : unkToken
                }
            }
        }

        var pieces: [String] = []
        var idx = n
        while idx > 0 {
            let prev = backPoint[idx]
            if prev < 0 { break }
            pieces.append(backToken[idx])
            idx = prev
        }
        return pieces.reversed()
    }
}

enum TokenizerError: Error {
    case invalidJSON
    case emptyVocab
}

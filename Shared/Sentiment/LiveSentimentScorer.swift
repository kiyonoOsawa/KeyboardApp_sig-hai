//
//  LiveSentimentScorer.swift
//  sb_26sp_app
//
//  キーボード拡張の中で、打鍵のたびに極性を出す。
//  WRIME の Core ML（約 647MB）は拡張のメモリに載らないため、
//  語彙の一致で -2〜+2 を推定する。
//

import Foundation

enum LiveSentimentScorer {
    private static let intensifiers = [
        "めちゃくちゃ", "めっちゃ", "とても", "すごく", "かなり", "本当に", "超", "まじ", "マジ"
    ]
    private static let phrases: [(String, Double)] = {
        let raw: [(String, Double)] = [
            ("大好き", 2.0), ("だいすき", 2.0), ("愛してる", 2.0), ("あいしてる", 2.0),
            ("幸せ", 1.8), ("しあわせ", 1.8), ("最高", 2.0), ("さいこう", 2.0),
            ("感謝", 1.6), ("かんしゃ", 1.6), ("ありがとう", 1.6),
            ("嬉しい", 1.5), ("うれしい", 1.5), ("嬉しく", 1.5), ("うれしく", 1.5),
            ("楽しい", 1.5), ("たのしい", 1.5), ("楽しく", 1.5), ("たのしく", 1.5),
            ("面白い", 1.3), ("おもしろい", 1.3), ("面白く", 1.3), ("おもしろく", 1.3),
            ("素晴らしい", 1.8), ("すばらしい", 1.8),
            ("良い", 1.0), ("よい", 1.0), ("よかった", 1.4), ("良かった", 1.4),
            ("いい感じ", 1.3), ("いいね", 1.2),
            ("好き", 1.4), ("すき", 1.4), ("好きだ", 1.5), ("すきだ", 1.5),
            ("大好きだ", 2.0), ("だいすきだ", 2.0),
            ("楽しみ", 1.2), ("たのしみ", 1.2), ("期待", 0.8), ("きたい", 0.8),
            ("安心", 1.0), ("あんしん", 1.0), ("穏やか", 0.8), ("おだやか", 0.8),
            ("きれい", 1.0), ("綺麗", 1.0), ("便利", 0.8), ("べんり", 0.8),
            ("助かる", 1.2), ("たすかる", 1.2), ("助かった", 1.3), ("たすかった", 1.3),
            ("美味しい", 1.3), ("おいしい", 1.3), ("美味しく", 1.3), ("おいしく", 1.3),
            ("うまい", 1.2), ("満足", 1.3), ("まんぞく", 1.3), ("快適", 1.2), ("かいてき", 1.2),
            ("元気", 1.0), ("げんき", 1.0), ("順調", 1.0), ("じゅんちょう", 1.0),
            ("成功", 1.4), ("せいこう", 1.4), ("勝てた", 1.2), ("かてた", 1.2), ("笑", 0.8),
            ("悲しい", -1.6), ("かなしい", -1.6), ("悲しく", -1.6), ("かなしく", -1.6),
            ("辛い", -1.5), ("つらい", -1.5), ("辛く", -1.5), ("つらく", -1.5),
            ("痛い", -1.2), ("いたい", -1.2), ("痛く", -1.2), ("いたく", -1.2),
            ("嫌い", -1.6), ("きらい", -1.6), ("嫌だ", -1.5), ("いやだ", -1.5), ("やだ", -1.3),
            ("むかつく", -1.6), ("イライラ", -1.4), ("最悪", -2.0), ("さいあく", -2.0),
            ("ひどい", -1.6), ("酷い", -1.6),
            ("つまらない", -1.3), ("つまらなく", -1.3), ("だるい", -1.1),
            ("疲れた", -1.2), ("つかれた", -1.2), ("疲れ", -0.9), ("つかれ", -0.9),
            ("しんどい", -1.4), ("不安", -1.2), ("ふあん", -1.2),
            ("心配", -1.0), ("しんぱい", -1.0), ("怖い", -1.3), ("こわい", -1.3), ("恐い", -1.3),
            ("うざい", -1.5), ("きもい", -1.6),
            ("気持ち悪い", -1.7), ("きもちわるい", -1.7),
            ("失望", -1.5), ("しつぼう", -1.5), ("残念", -1.1), ("ざんねん", -1.1),
            ("失敗", -1.3), ("しっぱい", -1.3), ("負けた", -1.1), ("まけた", -1.1),
            ("腹立つ", -1.5), ("はらたつ", -1.5), ("腹が立つ", -1.5), ("はらがたつ", -1.5),
            ("寂しい", -1.4), ("さびしい", -1.4), ("さみしい", -1.4),
            ("寂しく", -1.4), ("さびしく", -1.4), ("さみしく", -1.4),
            ("退屈", -0.9), ("たいくつ", -0.9), ("面倒", -0.9), ("めんどう", -0.9),
            ("めんどくさい", -1.2), ("無理", -1.0), ("むり", -1.0),
            ("ごめん", -0.6), ("すみません", -0.5),
            ("泣きたい", -1.6), ("なきたい", -1.6), ("泣いた", -1.2), ("ないた", -1.2),
            ("クソ", -1.4), ("くそ", -1.4),
            ("😊", 1.5), ("😄", 1.5), ("😂", 1.2), ("❤️", 1.6), ("👍", 1.0),
            ("😢", -1.4), ("😭", -1.7), ("😡", -1.6), ("👎", -1.0), ("💔", -1.5)
        ]
        return raw.sorted { $0.0.count > $1.0.count }
    }()

    private static let byFirst: [Character: [(String, Double)]] = {
        var map: [Character: [(String, Double)]] = [:]
        for entry in phrases {
            guard let first = entry.0.first else { continue }
            map[first, default: []].append(entry)
        }
        return map
    }()

    /// 空文字なら nil。語が無くても、入力中は中立として返す。
    static func score(_ text: String) -> SentimentResult? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var values: [Double] = []
        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            if let match = match(in: trimmed, at: index) {
                let end = trimmed.index(index, offsetBy: match.phrase.count)
                var value = match.score
                value = applyNegation(value, tail: trimmed[end...])
                value = applyIntensifier(value, head: trimmed[..<index])
                values.append(min(max(value, -2), 2))
                index = end
            } else {
                index = trimmed.index(after: index)
            }
        }

        let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        let clipped = min(max(average, -2), 2)
        return SentimentResult(
            text: trimmed,
            score: clipped,
            label: SentimentResult.label(for: clipped)
        )
    }

    private static func match(in text: String, at index: String.Index) -> (phrase: String, score: Double)? {
        guard let candidates = byFirst[text[index]] else { return nil }
        for (phrase, score) in candidates {
            guard let end = text.index(index, offsetBy: phrase.count, limitedBy: text.endIndex),
                  text[index..<end] == phrase else { continue }
            return (phrase, score)
        }
        return nil
    }

    private static func applyNegation(_ value: Double, tail: Substring) -> Double {
        let head = String(tail.prefix(8))
        if head.hasPrefix("なくない") || head.hasPrefix("なくはない") {
            return value
        }
        let flips = ["じゃない", "ではない", "ません", "ない", "ぬ", "ず"]
        if flips.contains(where: { head.hasPrefix($0) }) {
            return -value * 0.9
        }
        return value
    }

    private static func applyIntensifier(_ value: Double, head: Substring) -> Double {
        let prefix = String(head.suffix(8))
        guard intensifiers.contains(where: { prefix.hasSuffix($0) }) else { return value }
        return min(max(value * 1.25, -2), 2)
    }
}

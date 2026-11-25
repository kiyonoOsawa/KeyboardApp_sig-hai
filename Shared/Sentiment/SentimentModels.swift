//
//  SentimentModels.swift
//  sb_26sp_app
//

import Foundation

struct SentimentResult: Equatable, Sendable {
    let text: String
    let score: Double
    let label: String

    /// デノーマライズ (-1~+1 → -2~+2) + clip
    static func denormalize(_ raw: Double) -> Double {
        min(max(raw * 2.0, -2.0), 2.0)
    }

    static func label(for score: Double) -> String {
        if score <= -1.5 {
            return "強いネガティブ"
        } else if score < -0.5 {
            return "ネガティブ"
        } else if score <= 0.5 {
            return "中立"
        } else if score < 1.5 {
            return "ポジティブ"
        } else {
            return "強いポジティブ"
        }
    }

    /// 背面色の区分。±0.1 以内を基準（中立）とする。
    var polarity: SentimentPolarity {
        SentimentPolarity(score: score)
    }

    var consoleDescription: String {
        let barPosition = max(0, min(40, Int((score + 2) * 10)))
        let marker = String(repeating: " ", count: barPosition) + "▼"
        return """
        [SentimentLog]
        テキスト: \(text)
        感情極性: \(String(format: "%+.2f", score)) (\(label))

        [-2]────────────────[0]────────────────[+2]
        \(marker)
        """
    }
}

/// 判別にかかった時間をコンソールに出すときの書式
enum SentimentTiming {
    nonisolated static func text(_ duration: Duration) -> String {
        let seconds = duration / .seconds(1)
        return String(format: "%.3f秒（%.2fms）", seconds, seconds * 1000)
    }
}

enum SentimentPolarity: Equatable, Sendable {
    case positive
    case negative
    case neutral

    init(score: Double) {
        if score > 0.1 {
            self = .positive
        } else if score < -0.1 {
            self = .negative
        } else {
            self = .neutral
        }
    }
}

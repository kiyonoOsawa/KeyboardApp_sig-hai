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

//
//  SentenceInputLog.swift
//  sb_26sp_app
//

import Foundation
import SwiftData

@Model
final class SentenceInputLog {
    var id: UUID
    /// 一文が確定した時刻
    var timestamp: Date
    /// 入力し始めた時刻
    var startedAt: Date
    /// 入力された一文
    var text: String
    /// WRIME 感情極性 (-2.0 〜 +2.0)。未分析時は nil
    var sentimentScore: Double?
    /// 強いネガティブ〜強いポジティブ
    var sentimentLabel: String?
    /// キーボード上の即時推定。メインアプリの WRIME で上書きする前は true
    var sentimentIsLive: Bool?

    init(
        text: String,
        startedAt: Date,
        timestamp: Date = Date(),
        sentimentScore: Double? = nil,
        sentimentLabel: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.startedAt = startedAt
        self.timestamp = timestamp
        self.sentimentScore = sentimentScore
        self.sentimentLabel = sentimentLabel
    }
}

//
//  CandidateSentimentSetting.swift
//  sb_26sp_app
//

import Foundation

enum CandidateSentimentSetting {
    static let key = "candidateSentimentBadgeEnabled"

    /// 未設定のときはオン。キーボード拡張と本体アプリで同じ値を読む。
    static var isEnabled: Bool {
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        guard defaults.object(forKey: key) != nil else { return true }
        return defaults.bool(forKey: key)
    }
}

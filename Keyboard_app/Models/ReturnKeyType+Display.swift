//
//  ReturnKeyType+Display.swift
//  sb_26sp_app
//

import UIKit

extension UIReturnKeyType {
    var displayTitle: String {
        switch self {
        case .default: return "改行"
        case .go: return "Go"
        case .google: return "Google"
        case .join: return "参加"
        case .next: return "次へ"
        case .route: return "経路"
        case .search: return "検索"
        case .send: return "送信"
        case .yahoo: return "Yahoo"
        case .done: return "完了"
        case .emergencyCall: return "緊急"
        case .continue: return "続ける"
        @unknown default: return "決定"
        }
    }
}

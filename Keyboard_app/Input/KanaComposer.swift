//
//  KanaComposer.swift
//  sb_26sp_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

import Foundation

final class KanaComposer {

    enum KanaTransform {
        /// が行・ざ行・だ行・ば行
        case dakuten
        /// ぱ行（破裂音・半濁点）
        case handakuten
        /// ぁぃぅぇぉっゃゅょ
        case small
    }

    private static let dakutenMap: [Character: Character] = [
        "か": "が", "き": "ぎ", "く": "ぐ", "け": "げ", "こ": "ご",
        "さ": "ざ", "し": "じ", "す": "ず", "せ": "ぜ", "そ": "ぞ",
        "た": "だ", "ち": "ぢ", "つ": "づ", "て": "で", "と": "ど",
        "は": "ば", "ひ": "び", "ふ": "ぶ", "へ": "べ", "ほ": "ぼ",
        "う": "ゔ",
        "ぱ": "ば", "ぴ": "び", "ぷ": "ぶ", "ぺ": "べ", "ぽ": "ぼ",
    ]

    private static let handakutenMap: [Character: Character] = [
        "は": "ぱ", "ひ": "ぴ", "ふ": "ぷ", "へ": "ぺ", "ほ": "ぽ",
        "ば": "ぱ", "び": "ぴ", "ぶ": "ぷ", "べ": "ぺ", "ぼ": "ぽ",
        "ぱ": "は", "ぴ": "ひ", "ぷ": "ふ", "ぺ": "へ", "ぽ": "ほ",
    ]

    private static let smallMap: [Character: Character] = [
        "あ": "ぁ", "い": "ぃ", "う": "ぅ", "え": "ぇ", "お": "ぉ",
        "つ": "っ", "や": "ゃ", "ゆ": "ゅ", "よ": "ょ", "わ": "ゎ",
        "か": "ヵ", "け": "ヶ",
        "ぁ": "あ", "ぃ": "い", "ぅ": "う", "ぇ": "え", "ぉ": "お",
        "っ": "つ", "ゃ": "や", "ゅ": "ゆ", "ょ": "よ", "ゎ": "わ",
        "ヵ": "か", "ヶ": "け",
    ]

    func applyTransform(to previousChar: Character, type: KanaTransform) -> Character? {
        switch type {
        case .dakuten:
            return Self.dakutenMap[previousChar]
        case .handakuten:
            return Self.handakutenMap[previousChar]
        case .small:
            return Self.smallMap[previousChar]
        }
    }

    func transformType(for marker: String) -> KanaTransform? {
        switch marker {
        case "゛": return .dakuten
        case "゜": return .handakuten
        case "小": return .small
        default: return nil
        }
    }

    func label(for type: KanaTransform) -> String {
        switch type {
        case .dakuten: return "濁点"
        case .handakuten: return "破裂音"
        case .small: return "小文字"
        }
    }
}

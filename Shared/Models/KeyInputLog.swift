//
//  KeyInputLog.swift
//  sb_26sp_app
//

import Foundation
import SwiftData

@Model
final class KeyInputLog {
    var id: UUID
    var timestamp: Date
    /// 押したキーの中央ラベル（例: あ、空白、⌫）
    var keyLabel: String
    /// フリック方向（center / up / down / left / right）
    var flickDirection: String
    /// 実際に入力された文字（削除の場合は空）
    var outputText: String
    /// character / delete / space / nextKeyboard / voicing
    var actionType: String
    /// 入力直前の文脈（実験用）
    var documentContextBefore: String?

    init(
        keyLabel: String,
        flickDirection: String,
        outputText: String,
        actionType: String,
        documentContextBefore: String?
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.keyLabel = keyLabel
        self.flickDirection = flickDirection
        self.outputText = outputText
        self.actionType = actionType
        self.documentContextBefore = documentContextBefore
    }
}

//
//  KeyPressEvent.swift
//  sb_26sp_app
//

import Foundation

enum KeyInputActionType: String {
    case character
    case delete
    case space
    case `return`
    case nextKeyboard
    case voicing
}

struct KeyPressEvent {
    let keyLabel: String
    let flickDirection: String
    let outputText: String
    let actionType: KeyInputActionType
    let documentContextBefore: String?

    var consoleDescription: String {
        let output: String
        if outputText.isEmpty {
            switch actionType {
            case .delete: output = "（削除）"
            case .nextKeyboard: output = "（キーボード切替）"
            case .return: output = "（改行）"
            default: output = "（なし）"
            }
        } else if outputText == " " {
            output = "（空白）"
        } else {
            output = outputText
        }

        let direction: String = switch flickDirection {
        case "center": "タップ"
        case "up": "↑"
        case "down": "↓"
        case "left": "←"
        case "right": "→"
        default: flickDirection
        }

        let action: String = switch actionType {
        case .character: "文字入力"
        case .delete: "削除"
        case .space: "空白"
        case .return: "決定"
        case .nextKeyboard: "キーボード切替"
        case .voicing: "濁点・破裂音・小文字"
        }

        let context = documentContextBefore.map { " | 文脈: …\($0.suffix(30))" } ?? ""
        return "[KeyLog] キー: \(keyLabel) | 方向: \(direction) | 出力: \(output) | 操作: \(action)\(context)"
    }
}

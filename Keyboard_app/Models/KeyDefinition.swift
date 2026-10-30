//
//  KeyDefinition.swift
//  sb_26sp_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

struct FlickKey {
    let center: String          // 中央タップ（母音 a / あ行）
    let up: String?             // 上フリック（母音 u）
    let down: String?           // 下フリック（母音 o）
    let left: String?           // 左フリック（母音 i）
    let right: String?          // 右フリック（母音 e）
    let type: KeyType
    /// キー表面の表示。未指定なら center を出す
    var face: String? = nil

    enum KeyType {
        case kana, alphabet, number, special, space, delete, `return`, nextKeyboard
    }
}

// 50音配列
let kanaKeyLayout: [[FlickKey]] = [
    // 1行目
    [
        FlickKey(center: "あ", up: "う", down: "お", left: "い", right: "え", type: .kana),
        FlickKey(center: "か", up: "く", down: "こ", left: "き", right: "け", type: .kana),
        FlickKey(center: "さ", up: "す", down: "そ", left: "し", right: "せ", type: .kana),
    ],
    // 2行目
    [
        FlickKey(center: "た", up: "つ", down: "と", left: "ち", right: "て", type: .kana),
        FlickKey(center: "な", up: "ぬ", down: "の", left: "に", right: "ね", type: .kana),
        FlickKey(center: "は", up: "ふ", down: "ほ", left: "ひ", right: "へ", type: .kana),
    ],
    // 3行目
    [
        FlickKey(center: "ま", up: "む", down: "も", left: "み", right: "め", type: .kana),
        FlickKey(center: "や", up: "」", down: "よ", left: "「", right: "ゆ", type: .kana),
        FlickKey(center: "ら", up: "る", down: "ろ", left: "り", right: "れ", type: .kana),
    ],
    // 4行目
    [
        FlickKey(center: "☆", up: nil, down: nil, left: nil, right: nil, type: .special),
        FlickKey(center: "わ", up: "ん", down: "わ", left: "を", right: "ー", type: .kana),
        FlickKey(center: "゛", up: "っ", down: "ょ", left: "゜", right: "小", type: .kana, face: "゛゜小"),
    ],
    // 5行目（下段）
    [
        FlickKey(center: "⌨️", up: nil, down: nil, left: nil, right: nil, type: .nextKeyboard),
        FlickKey(center: "　", up: nil, down: nil, left: nil, right: nil, type: .space),
        FlickKey(center: "決定", up: nil, down: nil, left: nil, right: nil, type: .return),
        FlickKey(center: "⌫", up: nil, down: nil, left: nil, right: nil, type: .delete),
    ]
]

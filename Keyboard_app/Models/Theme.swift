//
//  Theme.swift
//  sb_26sp_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

import Foundation
import UIKit

private struct RGBA: Codable {
    let r: CGFloat
    let g: CGFloat
    let b: CGFloat
    let a: CGFloat

    init(_ color: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    var uiColor: UIColor {
        UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

struct Theme: Codable {
    var name: String
    var keyColor: UIColor
    var keyPressedColor: UIColor
    var backgroundColor: UIColor
    var keyTextColor: UIColor
    var candidateBarColor: UIColor

    init(
        name: String,
        keyColor: UIColor,
        keyPressedColor: UIColor,
        backgroundColor: UIColor,
        keyTextColor: UIColor,
        candidateBarColor: UIColor
    ) {
        self.name = name
        self.keyColor = keyColor
        self.keyPressedColor = keyPressedColor
        self.backgroundColor = backgroundColor
        self.keyTextColor = keyTextColor
        self.candidateBarColor = candidateBarColor
    }

    private enum CodingKeys: String, CodingKey {
        case name, keyColor, keyPressedColor, backgroundColor, keyTextColor, candidateBarColor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        keyColor = try container.decode(RGBA.self, forKey: .keyColor).uiColor
        keyPressedColor = try container.decode(RGBA.self, forKey: .keyPressedColor).uiColor
        backgroundColor = try container.decode(RGBA.self, forKey: .backgroundColor).uiColor
        keyTextColor = try container.decode(RGBA.self, forKey: .keyTextColor).uiColor
        candidateBarColor = try container.decode(RGBA.self, forKey: .candidateBarColor).uiColor
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(RGBA(keyColor), forKey: .keyColor)
        try container.encode(RGBA(keyPressedColor), forKey: .keyPressedColor)
        try container.encode(RGBA(backgroundColor), forKey: .backgroundColor)
        try container.encode(RGBA(keyTextColor), forKey: .keyTextColor)
        try container.encode(RGBA(candidateBarColor), forKey: .candidateBarColor)
    }

    static let `default` = Theme(
        name: "ライト",
        keyColor: .white,
        keyPressedColor: UIColor(white: 0.8, alpha: 1),
        backgroundColor: UIColor(white: 0.85, alpha: 1),
        keyTextColor: .black,
        candidateBarColor: .white
    )

    static let dark = Theme(
        name: "ダーク",
        keyColor: UIColor(white: 0.25, alpha: 1),
        keyPressedColor: UIColor(white: 0.35, alpha: 1),
        backgroundColor: UIColor(white: 0.15, alpha: 1),
        keyTextColor: .white,
        candidateBarColor: UIColor(white: 0.2, alpha: 1)
    )
}

class ThemeManager {
    static let shared = ThemeManager()
    private let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

    var currentTheme: Theme {
        get {
            guard let data = defaults.data(forKey: "theme"),
                  let theme = try? JSONDecoder().decode(Theme.self, from: data) else {
                return .default
            }
            return theme
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: "theme")
        }
    }
}

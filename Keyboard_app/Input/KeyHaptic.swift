//
//  KeyHaptic.swift
//  sb_26sp_app
//

import UIKit

enum KeyHaptic {
    /// 軽い衝撃のやや強め。連続打鍵でも重い振動にはしない
    private static let intensity: CGFloat = 0.75
    private static weak var attachedView: UIView?
    private static var generator: UIImpactFeedbackGenerator?

    /// 指が触れた時点で準備し、離した瞬間に遅れず鳴らす
    static func prepare(in view: UIView) {
        generator(for: view).prepare()
    }

    /// 一文字が入ったときだけ鳴らす。キーボード拡張では、表示中の view に結んだものでないと鳴らない
    static func playForCharacter(in view: UIView) {
        let generator = generator(for: view)
        generator.impactOccurred(intensity: intensity)
        generator.prepare()
    }

    private static func generator(for view: UIView) -> UIImpactFeedbackGenerator {
        if let generator, attachedView === view {
            return generator
        }
        let generator = UIImpactFeedbackGenerator(style: .light, view: view)
        self.generator = generator
        attachedView = view
        return generator
    }
}

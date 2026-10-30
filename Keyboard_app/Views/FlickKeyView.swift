//
//  FlickKeyView.swift
//  sb_26sp_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

import UIKit

final class FlickKeyView: UIView {
    private let key: FlickKey
    private var theme: Theme
    private let handler = FlickInputHandler()
    private let centerLabel = UILabel()
    private let previewView = FlickPreviewView()

    var keyType: FlickKey.KeyType { key.type }
    var onKeyPress: ((FlickKey, FlickDirection, String) -> Void)?
    var onSpecialKeyPress: ((FlickKey, FlickDirection) -> Void)?

    init(key: FlickKey, theme: Theme) {
        self.key = key
        self.theme = theme
        super.init(frame: .zero)
        setupUI()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme(_ theme: Theme) {
        self.theme = theme
        backgroundColor = theme.keyColor
        centerLabel.textColor = theme.keyTextColor
        previewView.applyTheme(theme)
    }

    func updateCenterLabel(_ text: String) {
        centerLabel.text = text
    }

    private func setupUI() {
        backgroundColor = theme.keyColor
        layer.cornerRadius = 6
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 1

        centerLabel.text = displayLabel
        centerLabel.textColor = theme.keyTextColor
        centerLabel.font = .systemFont(ofSize: keyFontSize, weight: .medium)
        centerLabel.textAlignment = .center
        centerLabel.adjustsFontSizeToFitWidth = true
        centerLabel.minimumScaleFactor = 0.6
        centerLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(centerLabel)

        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.isHidden = true
        addSubview(previewView)

        NSLayoutConstraint.activate([
            centerLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            centerLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            centerLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            previewView.centerXAnchor.constraint(equalTo: centerXAnchor),
            previewView.bottomAnchor.constraint(equalTo: topAnchor, constant: -4),
            previewView.widthAnchor.constraint(equalToConstant: 120),
            previewView.heightAnchor.constraint(equalToConstant: 120),
        ])
    }

    private var displayLabel: String {
        if let face = key.face { return face }
        switch key.type {
        case .space: return "空白"
        case .delete: return "⌫"
        case .nextKeyboard: return "🌐"
        case .return: return key.center
        default: return key.center
        }
    }

    private var keyFontSize: CGFloat {
        if key.face != nil { return 16 }
        switch key.type {
        case .space, .nextKeyboard, .return: return 14
        default: return 20
        }
    }

    private func setupGestures() {
        isUserInteractionEnabled = true

        handler.onTouchBegan = { [weak self] in
            guard let self else { return }
            self.animatePress(pressed: true)
            self.previewView.configure(key: self.key, theme: self.theme)
            self.previewView.isHidden = self.key.type != .kana
        }

        handler.onTouchEnded = { [weak self] direction in
            guard let self else { return }
            self.animatePress(pressed: false)
            self.previewView.isHidden = true
            self.handleInput(direction: direction)
        }
    }

    private func handleInput(direction: FlickDirection) {
        switch key.type {
        case .delete, .space, .nextKeyboard, .return:
            onSpecialKeyPress?(key, direction)
        case .special:
            if let char = character(for: direction) {
                onKeyPress?(key, direction, char)
            }
        default:
            if let char = character(for: direction) {
                onKeyPress?(key, direction, char)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        handler.handleTouchBegan(point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        let dir = handler.handleTouchMoved(point)
        previewView.updateHighlight(direction: dir)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        handler.handleTouchEnded(point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        animatePress(pressed: false)
        previewView.isHidden = true
    }

    private func character(for direction: FlickDirection) -> String? {
        switch direction {
        case .center: return key.center
        case .up:     return key.up ?? key.center
        case .down:   return key.down ?? key.center
        case .left:   return key.left ?? key.center
        case .right:  return key.right ?? key.center
        }
    }

    private func animatePress(pressed: Bool) {
        UIView.animate(withDuration: 0.08) {
            self.transform = pressed ? CGAffineTransform(scaleX: 0.94, y: 0.94) : .identity
            self.backgroundColor = pressed ? self.theme.keyPressedColor : self.theme.keyColor
        }
    }
}

// MARK: - FlickPreviewView

final class FlickPreviewView: UIView {
    private var labels: [FlickDirection: UILabel] = [:]
    private var theme: Theme = .default

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func applyTheme(_ theme: Theme) {
        self.theme = theme
        backgroundColor = theme.keyColor
        for label in labels.values {
            label.textColor = theme.keyTextColor
        }
    }

    func configure(key: FlickKey, theme: Theme) {
        self.theme = theme
        backgroundColor = theme.keyColor
        setText(key.center, for: .center)
        setText(key.up, for: .up)
        setText(key.down, for: .down)
        setText(key.left, for: .left)
        setText(key.right, for: .right)
        updateHighlight(direction: .center)
    }

    func updateHighlight(direction: FlickDirection) {
        for (dir, label) in labels {
            let isSelected = dir == direction
            label.font = .systemFont(ofSize: isSelected ? 22 : 16, weight: isSelected ? .bold : .regular)
            label.alpha = isSelected ? 1.0 : 0.5
            label.backgroundColor = isSelected ? theme.keyPressedColor : .clear
            label.layer.cornerRadius = 4
            label.clipsToBounds = true
        }
    }

    private func setup() {
        backgroundColor = theme.keyColor
        layer.cornerRadius = 8
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 4

        for direction in [FlickDirection.up, .left, .center, .right, .down] {
            let label = UILabel()
            label.textAlignment = .center
            label.textColor = theme.keyTextColor
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            labels[direction] = label
        }

        guard let up = labels[.up],
              let left = labels[.left],
              let center = labels[.center],
              let right = labels[.right],
              let down = labels[.down] else { return }

        NSLayoutConstraint.activate([
            center.centerXAnchor.constraint(equalTo: centerXAnchor),
            center.centerYAnchor.constraint(equalTo: centerYAnchor),
            center.widthAnchor.constraint(equalToConstant: 36),
            center.heightAnchor.constraint(equalToConstant: 36),

            up.centerXAnchor.constraint(equalTo: centerXAnchor),
            up.bottomAnchor.constraint(equalTo: center.topAnchor, constant: -2),
            up.widthAnchor.constraint(equalToConstant: 36),
            up.heightAnchor.constraint(equalToConstant: 36),

            down.centerXAnchor.constraint(equalTo: centerXAnchor),
            down.topAnchor.constraint(equalTo: center.bottomAnchor, constant: 2),
            down.widthAnchor.constraint(equalToConstant: 36),
            down.heightAnchor.constraint(equalToConstant: 36),

            left.centerYAnchor.constraint(equalTo: center.centerYAnchor),
            left.trailingAnchor.constraint(equalTo: center.leadingAnchor, constant: -2),
            left.widthAnchor.constraint(equalToConstant: 36),
            left.heightAnchor.constraint(equalToConstant: 36),

            right.centerYAnchor.constraint(equalTo: center.centerYAnchor),
            right.leadingAnchor.constraint(equalTo: center.trailingAnchor, constant: 2),
            right.widthAnchor.constraint(equalToConstant: 36),
            right.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func setText(_ text: String?, for direction: FlickDirection) {
        labels[direction]?.text = text
        labels[direction]?.isHidden = text == nil
    }
}

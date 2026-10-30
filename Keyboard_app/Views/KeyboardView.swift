//
//  KeyboardView.swift
//  sb_26sp_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

import UIKit

protocol KeyboardViewDelegate: AnyObject {
    func keyboardView(_ view: KeyboardView, didPress event: KeyPressEvent)
    func keyboardView(_ view: KeyboardView, didSelect candidate: ConversionCandidate)
}

final class KeyboardView: UIView {

    static let candidateBarHeight: CGFloat = 44

    weak var delegate: KeyboardViewDelegate?

    private var theme: Theme
    private let candidateBar: CandidateBarView
    private let rowStack = UIStackView()
    private weak var returnKeyView: FlickKeyView?
    private var returnKeyLabel = "決定"

    init(theme: Theme = .default) {
        self.theme = theme
        self.candidateBar = CandidateBarView(theme: theme)
        super.init(frame: .zero)
        setupUI()
        buildKeys()
    }

    required init?(coder: NSCoder) {
        self.theme = .default
        self.candidateBar = CandidateBarView(theme: .default)
        super.init(coder: coder)
        setupUI()
        buildKeys()
    }

    func updateTheme(_ theme: Theme) {
        self.theme = theme
        backgroundColor = theme.backgroundColor
        candidateBar.applyTheme(theme)
        for case let row as UIStackView in rowStack.arrangedSubviews {
            for case let keyView as FlickKeyView in row.arrangedSubviews {
                keyView.applyTheme(theme)
            }
        }
    }

    func updateReturnKeyLabel(_ label: String) {
        returnKeyLabel = label
        returnKeyView?.updateCenterLabel(label)
    }

    func setCandidates(_ candidates: [ConversionCandidate]) {
        candidateBar.setCandidates(candidates)
    }

    private func setupUI() {
        backgroundColor = theme.backgroundColor

        candidateBar.translatesAutoresizingMaskIntoConstraints = false
        candidateBar.onSelect = { [weak self] candidate in
            guard let self else { return }
            self.delegate?.keyboardView(self, didSelect: candidate)
        }
        addSubview(candidateBar)

        rowStack.axis = .vertical
        rowStack.spacing = 6
        rowStack.distribution = .fillEqually
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowStack)

        NSLayoutConstraint.activate([
            candidateBar.topAnchor.constraint(equalTo: topAnchor),
            candidateBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            candidateBar.heightAnchor.constraint(equalToConstant: Self.candidateBarHeight),

            rowStack.topAnchor.constraint(equalTo: candidateBar.bottomAnchor, constant: 4),
            rowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            rowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            rowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    private func buildKeys() {
        for (rowIndex, row) in kanaKeyLayout.enumerated() {
            let rowView = UIStackView()
            rowView.axis = .horizontal
            rowView.spacing = 6
            rowView.distribution = rowIndex == kanaKeyLayout.count - 1 ? .fill : .fillEqually
            rowView.translatesAutoresizingMaskIntoConstraints = false

            for key in row {
                let keyView = FlickKeyView(key: key, theme: theme)
                if key.type == .return {
                    returnKeyView = keyView
                }
                keyView.onKeyPress = { [weak self] key, direction, char in
                    guard let self else { return }
                    self.delegate?.keyboardView(self, didPress: KeyPressEvent(
                        keyLabel: key.center,
                        flickDirection: direction.logLabel,
                        outputText: char,
                        actionType: .character,
                        documentContextBefore: nil
                    ))
                }
                keyView.onSpecialKeyPress = { [weak self] key, direction in
                    guard let self else { return }
                    let actionType: KeyInputActionType
                    let output: String
                    switch key.type {
                    case .delete:
                        actionType = .delete
                        output = ""
                    case .space:
                        actionType = .space
                        output = " "
                    case .return:
                        actionType = .return
                        output = "\n"
                    case .nextKeyboard:
                        actionType = .nextKeyboard
                        output = ""
                    default:
                        return
                    }
                    self.delegate?.keyboardView(self, didPress: KeyPressEvent(
                        keyLabel: self.keyLabel(for: key),
                        flickDirection: direction.logLabel,
                        outputText: output,
                        actionType: actionType,
                        documentContextBefore: nil
                    ))
                }
                rowView.addArrangedSubview(keyView)
            }

            if rowIndex == kanaKeyLayout.count - 1, rowView.arrangedSubviews.count == 4 {
                let nextKey = rowView.arrangedSubviews[0]
                let spaceKey = rowView.arrangedSubviews[1]
                let returnKey = rowView.arrangedSubviews[2]
                let deleteKey = rowView.arrangedSubviews[3]
                NSLayoutConstraint.activate([
                    nextKey.widthAnchor.constraint(equalTo: deleteKey.widthAnchor),
                    returnKey.widthAnchor.constraint(equalTo: deleteKey.widthAnchor),
                    spaceKey.widthAnchor.constraint(equalTo: nextKey.widthAnchor, multiplier: 2.0),
                ])
            }

            for keyView in rowView.arrangedSubviews {
                keyView.heightAnchor.constraint(greaterThanOrEqualToConstant: 46).isActive = true
            }

            rowStack.addArrangedSubview(rowView)
        }
    }

    private func keyLabel(for key: FlickKey) -> String {
        switch key.type {
        case .space: return "空白"
        case .delete: return "⌫"
        case .nextKeyboard: return "🌐"
        case .return: return returnKeyLabel
        default: return key.center
        }
    }
}

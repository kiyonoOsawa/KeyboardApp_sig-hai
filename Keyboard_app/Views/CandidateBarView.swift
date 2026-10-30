//
//  CandidateBarView.swift
//  sb_26sp_app
//

import UIKit

final class CandidateBarView: UIView {
    var onSelect: ((ConversionCandidate) -> Void)?

    private var theme: Theme
    private var candidates: [ConversionCandidate] = []
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let placeholder = UILabel()
    private let separator = UIView()
    private var separatorHeight: NSLayoutConstraint?

    init(theme: Theme) {
        self.theme = theme
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        self.theme = .default
        super.init(coder: coder)
        setup()
    }

    func applyTheme(_ theme: Theme) {
        guard theme.name != self.theme.name else { return }
        self.theme = theme
        backgroundColor = theme.candidateBarColor
        rebuild()
    }

    func setCandidates(_ candidates: [ConversionCandidate]) {
        guard candidates != self.candidates else { return }
        self.candidates = candidates
        rebuild()
    }

    private func setup() {
        backgroundColor = theme.candidateBarColor

        placeholder.text = "変換候補"
        placeholder.font = .systemFont(ofSize: 13)
        placeholder.textColor = .secondaryLabel
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholder)

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.delaysContentTouches = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            placeholder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            placeholder.centerYAnchor.constraint(equalTo: centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            stack.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let height = separator.heightAnchor.constraint(equalToConstant: hairline)
        height.isActive = true
        separatorHeight = height
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        separatorHeight?.constant = hairline
    }

    private var hairline: CGFloat {
        let scale = traitCollection.displayScale
        return scale > 0 ? 1 / scale : 0.5
    }

    private func rebuild() {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let hasCandidates = !candidates.isEmpty
        placeholder.isHidden = hasCandidates
        scrollView.isHidden = !hasCandidates
        guard hasCandidates else { return }

        for candidate in candidates {
            stack.addArrangedSubview(makeButton(for: candidate))
        }
        scrollView.setContentOffset(.zero, animated: false)
    }

    private func makeButton(for candidate: ConversionCandidate) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = candidate.text
        config.baseForegroundColor = theme.keyTextColor
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        config.background.cornerRadius = 6
        config.background.strokeWidth = 1
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16, weight: candidate.isReading ? .regular : .semibold)
            return outgoing
        }
        if candidate.isReading {
            config.background.backgroundColor = .clear
            config.background.strokeColor = theme.keyTextColor.withAlphaComponent(0.28)
        } else {
            config.background.backgroundColor = theme.keyColor
            config.background.strokeColor = theme.keyTextColor.withAlphaComponent(0.12)
        }

        let button = UIButton(configuration: config)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        button.configurationUpdateHandler = { button in
            button.alpha = button.isHighlighted ? 0.55 : 1
        }
        button.addAction(UIAction { [weak self] _ in
            self?.onSelect?(candidate)
        }, for: .touchUpInside)
        return button
    }
}

//
//  CandidateBarView.swift
//  sb_26sp_app
//

import UIKit

final class CandidateBarView: UIView {
    var onSelect: ((ConversionCandidate) -> Void)?

    private var theme: Theme
    private(set) var currentPolarity: SentimentPolarity = .neutral
    private var candidates: [ConversionCandidate] = []
    private var sentimentResult: SentimentResult?
    private var showsSentimentBadge = true
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let placeholder = UILabel()
    private let sentimentBadge = UIView()
    private let polarityDot = UIView()
    private let sentimentLabel = UILabel()
    private let separator = UIView()
    private var separatorHeight: NSLayoutConstraint?
    private var scrollTrailingToBadge: NSLayoutConstraint?
    private var scrollTrailingToEdge: NSLayoutConstraint?

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
        backgroundColor = .clear
        rebuild()
    }

    func setLiveSentiment(_ result: SentimentResult?, showsBadge: Bool) {
        sentimentResult = result
        showsSentimentBadge = showsBadge
        updateSentimentBadge()
    }

    func setBadgeEnabled(_ enabled: Bool) {
        showsSentimentBadge = enabled
        updateSentimentBadge()
    }

    func applyPolarityTint(_ polarity: SentimentPolarity) {
        currentPolarity = polarity
        let onColor = polarity != .neutral
        placeholder.textColor = onColor ? UIColor.white.withAlphaComponent(0.9) : .secondaryLabel
    }

    func setCandidates(_ candidates: [ConversionCandidate]) {
        guard candidates != self.candidates else { return }
        self.candidates = candidates
        rebuild()
    }

    private func setup() {
        backgroundColor = .clear

        placeholder.text = "変換候補"
        placeholder.font = .systemFont(ofSize: 13)
        placeholder.textColor = .secondaryLabel
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholder)

        sentimentBadge.isHidden = true
        sentimentBadge.layer.cornerRadius = 13
        sentimentBadge.layer.cornerCurve = .continuous
        sentimentBadge.layer.borderWidth = 1
        sentimentBadge.clipsToBounds = true
        sentimentBadge.translatesAutoresizingMaskIntoConstraints = false
        sentimentBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        addSubview(sentimentBadge)

        polarityDot.layer.cornerRadius = 4
        polarityDot.translatesAutoresizingMaskIntoConstraints = false
        sentimentBadge.addSubview(polarityDot)

        sentimentLabel.font = .systemFont(ofSize: 13, weight: .bold)
        sentimentLabel.translatesAutoresizingMaskIntoConstraints = false
        sentimentBadge.addSubview(sentimentLabel)

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
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            sentimentBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            sentimentBadge.centerYAnchor.constraint(equalTo: centerYAnchor),
            sentimentBadge.heightAnchor.constraint(equalToConstant: 26),

            polarityDot.leadingAnchor.constraint(equalTo: sentimentBadge.leadingAnchor, constant: 8),
            polarityDot.centerYAnchor.constraint(equalTo: sentimentBadge.centerYAnchor),
            polarityDot.widthAnchor.constraint(equalToConstant: 8),
            polarityDot.heightAnchor.constraint(equalToConstant: 8),

            sentimentLabel.leadingAnchor.constraint(equalTo: polarityDot.trailingAnchor, constant: 6),
            sentimentLabel.trailingAnchor.constraint(equalTo: sentimentBadge.trailingAnchor, constant: -10),
            sentimentLabel.centerYAnchor.constraint(equalTo: sentimentBadge.centerYAnchor),

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

        scrollTrailingToBadge = scrollView.trailingAnchor.constraint(equalTo: sentimentBadge.leadingAnchor, constant: -4)
        scrollTrailingToEdge = scrollView.trailingAnchor.constraint(equalTo: trailingAnchor)
        scrollTrailingToEdge?.isActive = true
    }

    private func updateSentimentBadge() {
        guard showsSentimentBadge, let result = sentimentResult else {
            sentimentBadge.isHidden = true
            scrollTrailingToBadge?.isActive = false
            scrollTrailingToEdge?.isActive = true
            return
        }
        sentimentLabel.text = badgeTitle(for: result)
        applyBadgeStyle(result.polarity)
        sentimentBadge.isHidden = false
        scrollTrailingToEdge?.isActive = false
        scrollTrailingToBadge?.isActive = true
    }

    private func applyBadgeStyle(_ polarity: SentimentPolarity) {
        let fill: UIColor
        let ink: UIColor
        switch polarity {
        case .positive:
            fill = UIColor(red: 1.00, green: 0.92, blue: 0.90, alpha: 1)
            ink = UIColor(red: 0.78, green: 0.10, blue: 0.12, alpha: 1)
        case .negative:
            fill = UIColor(red: 0.90, green: 0.94, blue: 1.00, alpha: 1)
            ink = UIColor(red: 0.10, green: 0.28, blue: 0.72, alpha: 1)
        case .neutral:
            fill = UIColor(white: 0.96, alpha: 1)
            ink = UIColor(white: 0.28, alpha: 1)
        }
        sentimentBadge.backgroundColor = fill
        sentimentBadge.layer.borderColor = ink.withAlphaComponent(0.45).cgColor
        sentimentLabel.textColor = ink
        polarityDot.backgroundColor = ink
    }

    /// 色と文言を揃える。背面色と同じ ±0.1 でポジティブ / ネガティブ / 中立を分ける
    private func badgeTitle(for result: SentimentResult) -> String {
        switch result.polarity {
        case .positive:
            return result.score >= 1.5 ? "強いポジティブ" : "ポジティブ"
        case .negative:
            return result.score <= -1.5 ? "強いネガティブ" : "ネガティブ"
        case .neutral:
            return "中立"
        }
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

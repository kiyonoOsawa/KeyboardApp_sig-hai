//
//  KeyboardViewController.swift
//  Keyboard_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

import UIKit

class KeyboardViewController: UIInputViewController {

    private var keyboardView: KeyboardView!
    private let composer = KanaComposer()
    private let logStore = InputLogStore.shared
    private let sentenceTracker = SentenceSessionTracker.shared
    private var heightConstraint: NSLayoutConstraint?
    /// まだ漢字にしていない、文末のひらがな
    private var composing = ""
    /// 打鍵が止まったあとに、そこまでの文を一度だけ判定する
    private var sentimentWorkItem: DispatchWorkItem?
    /// 入力欄が替わったら、前の文の判定を持ち越さない
    private var lastDocumentID: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()

        // フルアクセス時のみ App Group / SwiftData が使える
        logStore.configure()
        if !hasFullAccess {
            print("[Keyboard] フルアクセスが OFF のためログ保存できません。設定で有効にしてください。")
        }

        let theme = currentTheme()
        keyboardView = KeyboardView(theme: theme)
        keyboardView.delegate = self
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)

        KanaKanjiDictionary.shared.preload { [weak self] in
            self?.refreshCandidates()
        }

        NSLayoutConstraint.activate([
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        updateKeyboardHeight()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        resetSessionIfDocumentChanged()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateKeyboardHeight()
        keyboardView?.updateTheme(currentTheme())
        keyboardView?.updateReturnKeyLabel(textDocumentProxy.returnKeyType?.displayTitle ?? "決定")
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateKeyboardHeight()
        })
    }

    private func updateKeyboardHeight() {
        let height = keyboardHeight(for: traitCollection, screenSize: view.bounds.size)
        if let heightConstraint {
            heightConstraint.constant = height
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: height)
            constraint.priority = .required
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    private static func preferredKeyboardHeight(for traits: UITraitCollection, screenSize: CGSize) -> CGFloat {
        if traits.userInterfaceIdiom == .pad {
            return 352
        }

        let longestSide = max(screenSize.width, screenSize.height)
        switch longestSide {
        case ..<667:  return 258
        case ..<736:  return 271
        case ..<812:  return 291
        case ..<896:  return 301
        default:      return 319
        }
    }

    private func keyboardHeight(for traits: UITraitCollection, screenSize: CGSize) -> CGFloat {
        Self.preferredKeyboardHeight(for: traits, screenSize: screenSize) + KeyboardView.candidateBarHeight
    }

    private func currentTheme() -> Theme {
        textDocumentProxy.keyboardAppearance == .dark ? .dark : .default
    }

    private func recordKeyLog(_ event: KeyPressEvent) {
        let enriched = KeyPressEvent(
            keyLabel: event.keyLabel,
            flickDirection: event.flickDirection,
            outputText: event.outputText,
            actionType: event.actionType,
            documentContextBefore: textDocumentProxy.documentContextBeforeInput
        )
        logStore.log(enriched)
    }

    @discardableResult
    private func commitSentence() -> SentimentResult? {
        let live = LiveSentimentScorer.score(sentenceTracker.currentText)
        guard let sentence = sentenceTracker.commit() else { return nil }
        logStore.logSentence(text: sentence.text, startedAt: sentence.startedAt, liveSentiment: live)
        return live
    }

    private func handleKanaTransform(_ marker: String, event: KeyPressEvent) {
        let contextBefore = textDocumentProxy.documentContextBeforeInput
        guard let transform = composer.transformType(for: marker) else { return }
        guard let before = contextBefore,
              let lastChar = before.last,
              let transformed = composer.applyTransform(to: lastChar, type: transform) else {
            // 小文字にできない文字へ「小」自体は入れない
            guard transform != .small else { return }
            textDocumentProxy.insertText(marker)
            sentenceTracker.append(marker)
            noteInserted(marker)
            recordKeyLog(KeyPressEvent(
                keyLabel: event.keyLabel,
                flickDirection: event.flickDirection,
                outputText: marker,
                actionType: .character,
                documentContextBefore: contextBefore
            ))
            return
        }
        textDocumentProxy.deleteBackward()
        textDocumentProxy.insertText(String(transformed))
        sentenceTracker.handleDelete()
        sentenceTracker.append(String(transformed))
        noteDeleted()
        noteInserted(String(transformed))
        recordKeyLog(KeyPressEvent(
            keyLabel: composer.label(for: transform),
            flickDirection: event.flickDirection,
            outputText: String(transformed),
            actionType: .voicing,
            documentContextBefore: before
        ))
    }

    private func refreshCandidates() {
        guard !composing.isEmpty else {
            keyboardView?.setCandidates([])
            return
        }
        var items = KanaKanjiDictionary.shared.candidates(for: composing)
        items.insert(ConversionCandidate(text: composing, isReading: true), at: 0)
        keyboardView?.setCandidates(items)
    }

    private func noteInserted(_ text: String) {
        if Self.isComposingKana(text) {
            composing += text
        } else {
            let wasConverting = !composing.isEmpty
            composing = ""
            finishConversionIfStopped(wasConverting: wasConverting)
        }
    }

    private func noteDeleted() {
        let wasConverting = !composing.isEmpty
        if !composing.isEmpty {
            composing.removeLast()
        }
        finishConversionIfStopped(wasConverting: wasConverting)
    }

    private func apply(candidate: ConversionCandidate) {
        guard !composing.isEmpty else {
            refreshCandidates()
            return
        }
        if candidate.isReading || candidate.text == composing {
            composing = ""
            refreshCandidates()
            publishLiveSentiment()
            return
        }

        let contextBefore = textDocumentProxy.documentContextBeforeInput
        let deleteCount = composing.count
        recordKeyLog(KeyPressEvent(
            keyLabel: "変換",
            flickDirection: "center",
            outputText: candidate.text,
            actionType: .character,
            documentContextBefore: contextBefore
        ))
        for _ in 0..<deleteCount {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(candidate.text)
        sentenceTracker.replaceTail(count: deleteCount, with: candidate.text)
        composing = ""
        refreshCandidates()
        publishLiveSentiment()
    }

    private static func isComposingKana(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        return text.unicodeScalars.allSatisfy { scalar in
            scalar.value == 0x30FC || scalar.value == 0x30F5 || scalar.value == 0x30F6
                || (0x3041...0x3094).contains(scalar.value)
        }
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ view: KeyboardView, didSelect candidate: ConversionCandidate) {
        apply(candidate: candidate)
    }

    func keyboardView(_ view: KeyboardView, didPress event: KeyPressEvent) {
        resetSessionIfDocumentChanged()
        let contextBefore = textDocumentProxy.documentContextBeforeInput
        var scoreWhenPaused = true

        defer {
            scheduleCandidateRefresh()
            if scoreWhenPaused {
                scheduleLiveSentiment()
            } else {
                sentimentWorkItem?.cancel()
            }
        }

        switch event.actionType {
        case .character:
            if composer.transformType(for: event.outputText) != nil {
                handleKanaTransform(event.outputText, event: event)
                return
            }
            textDocumentProxy.insertText(event.outputText)
            sentenceTracker.append(event.outputText)
            noteInserted(event.outputText)
            recordKeyLog(KeyPressEvent(
                keyLabel: event.keyLabel,
                flickDirection: event.flickDirection,
                outputText: event.outputText,
                actionType: .character,
                documentContextBefore: contextBefore
            ))

        case .delete:
            let beforeCount = contextBefore?.count ?? 0
            let selectedCount = textDocumentProxy.selectedText?.count ?? 0
            textDocumentProxy.deleteBackward()
            if isPlaceholderState {
                sentenceTracker.discard()
                composing = ""
                publishLiveSentiment()
            } else if selectedCount > 0 {
                let wasConverting = !composing.isEmpty
                sentenceTracker.removeLast(selectedCount)
                composing = ""
                finishConversionIfStopped(wasConverting: wasConverting)
            } else {
                let afterCount = textDocumentProxy.documentContextBeforeInput?.count ?? beforeCount
                let removed = max(beforeCount - afterCount, 1)
                sentenceTracker.removeLast(removed)
                if removed == 1 {
                    noteDeleted()
                } else {
                    let wasConverting = !composing.isEmpty
                    composing = ""
                    finishConversionIfStopped(wasConverting: wasConverting)
                }
            }
            recordKeyLog(KeyPressEvent(
                keyLabel: event.keyLabel,
                flickDirection: event.flickDirection,
                outputText: "",
                actionType: .delete,
                documentContextBefore: contextBefore
            ))

        case .space:
            textDocumentProxy.insertText(" ")
            sentenceTracker.append(" ")
            let wasConverting = !composing.isEmpty
            composing = ""
            finishConversionIfStopped(wasConverting: wasConverting)
            recordKeyLog(KeyPressEvent(
                keyLabel: event.keyLabel,
                flickDirection: event.flickDirection,
                outputText: " ",
                actionType: .space,
                documentContextBefore: contextBefore
            ))

        case .return:
            scoreWhenPaused = false
            composing = ""
            keyboardView?.setLiveSentiment(commitSentence())
            textDocumentProxy.insertText("\n")
            recordKeyLog(KeyPressEvent(
                keyLabel: event.keyLabel,
                flickDirection: event.flickDirection,
                outputText: "\n",
                actionType: .return,
                documentContextBefore: contextBefore
            ))

        case .nextKeyboard:
            scoreWhenPaused = false
            composing = ""
            let live = LiveSentimentScorer.score(sentenceTracker.currentText)
            if let sentence = sentenceTracker.flush() {
                logStore.logSentence(text: sentence.text, startedAt: sentence.startedAt, liveSentiment: live)
            }
            keyboardView?.setLiveSentiment(live)
            recordKeyLog(KeyPressEvent(
                keyLabel: event.keyLabel,
                flickDirection: event.flickDirection,
                outputText: "",
                actionType: .nextKeyboard,
                documentContextBefore: contextBefore
            ))
            advanceToNextInputMode()

        case .voicing:
            break
        }
    }

    /// 文字入力を先に返し、候補の引き直しは次のターンで行う
    private func scheduleCandidateRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshCandidates()
        }
    }

    /// 変換中の読みが確定・中断されたときだけ、そこまでの文をすぐ分析する
    private func finishConversionIfStopped(wasConverting: Bool) {
        guard wasConverting, composing.isEmpty else { return }
        sentimentWorkItem?.cancel()
        publishLiveSentiment()
    }

    /// かなを打ち続けているあいだは待って、止まったらそこまでの文を分析する
    private func scheduleLiveSentiment() {
        sentimentWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.publishLiveSentiment()
        }
        sentimentWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    private func publishLiveSentiment() {
        keyboardView?.setLiveSentiment(LiveSentimentScorer.score(sentenceTracker.currentText))
    }

    /// 別の入力欄に移ったときだけ文を捨てる。
    /// 同じ欄の textDidChange で空欄扱いにすると、1回目のあと毎回文が消えて判定が止まる。
    private func resetSessionIfDocumentChanged() {
        let identifier = textDocumentProxy.documentIdentifier
        guard lastDocumentID != identifier else { return }
        lastDocumentID = identifier
        sentenceTracker.discard()
        composing = ""
        sentimentWorkItem?.cancel()
        publishLiveSentiment()
        refreshCandidates()
    }

    /// 文脈が取れているときだけ、空欄（プレースホルダー）と判断する。
    /// 実機では入力中でも文脈が nil になる。nil を空とみなすと、毎打鍵で分析が消える。
    private var isPlaceholderState: Bool {
        let before = textDocumentProxy.documentContextBeforeInput
        let after = textDocumentProxy.documentContextAfterInput
        guard let before, let after else { return false }
        return before.isEmpty && after.isEmpty
    }
}

//
//  SentenceSessionTracker.swift
//  sb_26sp_app
//

import Foundation

/// 入力開始（プレースホルダー消失）から空状態に戻るまでを1セッションとして追跡する
@MainActor
final class SentenceSessionTracker {
    static let shared = SentenceSessionTracker()

    private(set) var isActive = false
    private var buffer = ""
    private var startedAt = Date()

    var currentText: String { buffer }

    private init() {}

    /// 文字・空白・濁点変換結果をセッションに追加
    func append(_ text: String) {
        guard !text.isEmpty else { return }
        if !isActive {
            isActive = true
            startedAt = Date()
            buffer = ""
        }
        buffer += text
    }

    /// 未確定読みを変換結果で置き換える。セッション開始時刻は維持する
    func replaceTail(count: Int, with text: String) {
        if !isActive {
            append(text)
            return
        }
        let drop = min(max(count, 0), buffer.count)
        if drop > 0 {
            buffer.removeLast(drop)
        }
        buffer += text
        if buffer.isEmpty {
            reset()
        }
    }

    /// 削除キー。バッファが空になったらセッション終了（プレースホルダー状態に復帰）
    func handleDelete() {
        removeLast(1)
    }

    func removeLast(_ count: Int) {
        guard isActive, count > 0 else { return }
        let drop = min(count, buffer.count)
        if drop > 0 {
            buffer.removeLast(drop)
        }
        if buffer.isEmpty {
            reset()
        }
    }

    /// 入力欄がプレースホルダーに戻ったとき、前の文を分析対象から外す
    func discard() {
        reset()
    }

    /// 決定・改行で一文を確定
    func commit() -> (text: String, startedAt: Date)? {
        guard isActive, !buffer.isEmpty else {
            reset()
            return nil
        }
        let result = (text: buffer, startedAt: startedAt)
        reset()
        return result
    }

    /// キーボード切替などで未確定の一文を保存
    func flush() -> (text: String, startedAt: Date)? {
        commit()
    }

    private func reset() {
        isActive = false
        buffer = ""
    }
}

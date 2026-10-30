//
//  ConversionEngine.swift
//  sb_26sp_app
//
//  SKK-JISYO.L（GPL-2.0, https://github.com/skk-dev/dict）から作った
//  kanji_dict.txt を引き、未確定のひらがなに対する変換候補を返す。
//

import Foundation

struct ConversionCandidate: Equatable {
    /// 候補バーに出す文字列。選ぶと未確定の読み全体と置き換わる
    let text: String
    /// 読みそのもの。選ぶと文書は変えず、未確定状態だけを閉じる
    let isReading: Bool
}

final class KanaKanjiDictionary {
    static let shared = KanaKanjiDictionary()

    private var nasi = LineDictionary(text: "")
    private var ari = LineDictionary(text: "")
    private(set) var isReady = false
    private var started = false

    private static let particles: Set<Character> = [
        "は", "が", "を", "に", "の", "で", "へ", "と", "や", "も", "ね", "よ", "か", "わ"
    ]

    private static let okuriHead: [Character: Character] = [
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
        "ぁ": "a", "ぃ": "i", "ぅ": "u", "ぇ": "e", "ぉ": "o",
        "か": "k", "き": "k", "く": "k", "け": "k", "こ": "k",
        "が": "g", "ぎ": "g", "ぐ": "g", "げ": "g", "ご": "g",
        "さ": "s", "し": "s", "す": "s", "せ": "s", "そ": "s",
        "ざ": "z", "じ": "z", "ず": "z", "ぜ": "z", "ぞ": "z",
        "た": "t", "ち": "t", "つ": "t", "て": "t", "と": "t",
        "だ": "d", "ぢ": "d", "づ": "d", "で": "d", "ど": "d",
        "な": "n", "に": "n", "ぬ": "n", "ね": "n", "の": "n",
        "は": "h", "ひ": "h", "ふ": "h", "へ": "h", "ほ": "h",
        "ば": "b", "び": "b", "ぶ": "b", "べ": "b", "ぼ": "b",
        "ぱ": "p", "ぴ": "p", "ぷ": "p", "ぺ": "p", "ぽ": "p",
        "ま": "m", "み": "m", "む": "m", "め": "m", "も": "m",
        "や": "y", "ゆ": "y", "よ": "y",
        "ゃ": "y", "ゅ": "y", "ょ": "y",
        "ら": "r", "り": "r", "る": "r", "れ": "r", "ろ": "r",
        "わ": "w", "を": "w", "ん": "n",
        "ゎ": "w",
    ]

    private init() {}

    func preload(completion: @escaping () -> Void) {
        if isReady {
            completion()
            return
        }
        guard !started else { return }
        started = true

        DispatchQueue.global(qos: .userInitiated).async {
            let loaded: (LineDictionary, LineDictionary)?
            if let url = Self.bundleURL() {
                loaded = try? Self.dictionaries(from: url)
            } else {
                loaded = nil
                print("[Conversion] kanji_dict.txt がバンドルにありません")
            }
            DispatchQueue.main.async {
                if let loaded {
                    self.nasi = loaded.0
                    self.ari = loaded.1
                    print("[Conversion] 辞書準備完了 見出し=\(loaded.0.lineCount) 送り=\(loaded.1.lineCount)")
                }
                self.isReady = true
                completion()
            }
        }
    }

    func loadSynchronously(from url: URL) throws {
        let loaded = try Self.dictionaries(from: url)
        nasi = loaded.0
        ari = loaded.1
        isReady = true
        started = true
    }

    func candidates(for reading: String) -> [ConversionCandidate] {
        guard isReady, !reading.isEmpty else { return [] }

        var seen = Set<String>()
        var ordered: [String] = []
        func push(_ text: String) {
            guard text != reading, !text.isEmpty, seen.insert(text).inserted else { return }
            ordered.append(text)
            if ordered.count > 16 { return }
        }

        let exact = nasi.values(for: reading)
        let particle = particleSurfaces(for: reading)
        if particle.isEmpty {
            for text in exact { push(text) }
        } else {
            for text in particle { push(text) }
            for text in exact { push(text) }
        }
        for text in okuriSurfaces(for: reading) { push(text) }

        let wantsCompletion = exact.isEmpty || reading.count <= 2
        if wantsCompletion, ordered.count < 12 {
            for text in completions(of: reading, limit: 6) { push(text) }
        }

        return ordered.prefix(12).map { ConversionCandidate(text: $0, isReading: false) }
    }

    private func particleSurfaces(for reading: String) -> [String] {
        guard let last = reading.last, Self.particles.contains(last), reading.count >= 2 else {
            return []
        }
        let stem = String(reading.dropLast())
        return nasi.values(for: stem).map { $0 + String(last) }
    }

    private func okuriSurfaces(for reading: String) -> [String] {
        let chars = Array(reading)
        guard chars.count >= 2 else { return [] }
        let maxOkuri = min(3, chars.count - 1)
        let smallKana: Set<Character> = ["ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ"]
        for okuriLength in 1...maxOkuri {
            let stem = String(chars.prefix(chars.count - okuriLength))
            let okuri = String(chars.suffix(okuriLength))
            guard let first = okuri.first, !smallKana.contains(first) else { continue }
            let stemCount = chars.count - okuriLength
            let isSokuon = first == "っ"
            // 「きょう」「にほん」を「き+ょう」「に+ほん」と誤って割らない
            if okuriLength >= 2, stemCount < 2, !isSokuon { continue }
            if okuriLength >= 3, stemCount < 2 { continue }
            guard let letter = okuriLetter(of: okuri) else { continue }
            let key = stem + String(letter)
            let hits = ari.values(for: key).map { $0 + okuri }
            if !hits.isEmpty {
                return Array(hits.prefix(4))
            }
        }
        return []
    }

    private func okuriLetter(of okuri: String) -> Character? {
        let chars = Array(okuri)
        guard let first = chars.first else { return nil }
        if first == "っ" {
            guard chars.count >= 2 else { return nil }
            return Self.okuriHead[chars[1]]
        }
        return Self.okuriHead[first]
    }

    private func completions(of reading: String, limit: Int) -> [String] {
        guard reading.count >= 2, limit > 0 else { return [] }
        var plusOne: [String] = []
        var plusTwo: [String] = []
        var scanned = 0
        var index = nasi.lowerBound(reading)
        while index < nasi.lineCount, scanned < 1500 {
            let key = nasi.key(at: index)
            if !key.hasPrefix(reading) { break }
            let extra = key.count - reading.count
            if extra == 1, plusOne.count < limit, let surface = nasi.values(at: index).first {
                plusOne.append(surface)
            } else if extra == 2, plusTwo.count < limit, let surface = nasi.values(at: index).first {
                plusTwo.append(surface)
            }
            index += 1
            scanned += 1
            if plusOne.count >= limit && plusTwo.count >= limit { break }
        }
        return Array((plusOne + plusTwo).prefix(limit))
    }

    private static func bundleURL() -> URL? {
        Bundle.main.url(forResource: "kanji_dict", withExtension: "txt")
            ?? Bundle.main.url(forResource: "kanji_dict", withExtension: "txt", subdirectory: "Resources")
    }

    private static func dictionaries(from url: URL) throws -> (LineDictionary, LineDictionary) {
        let raw = try String(contentsOf: url, encoding: .utf8)
        let parts = raw.components(separatedBy: "%%ARI%%\n")
        let nasi = LineDictionary(text: parts[0])
        let ari = parts.count > 1 ? LineDictionary(text: parts[1]) : LineDictionary(text: "")
        return (nasi, ari)
    }
}

/// コードポイント順に並んだ TSV を、行頭インデックスで二分探索する。
private final class LineDictionary {
    private let text: String
    private let starts: [String.Index]

    var lineCount: Int { starts.count }

    init(text: String) {
        self.text = text
        var starts: [String.Index] = []
        starts.reserveCapacity(text.utf8.count / 16)
        var index = text.startIndex
        if index < text.endIndex {
            starts.append(index)
        }
        while index < text.endIndex, let newline = text[index...].firstIndex(of: "\n") {
            let next = text.index(after: newline)
            if next < text.endIndex {
                starts.append(next)
            }
            index = next
        }
        self.starts = starts
    }

    func values(for key: String) -> [String] {
        let index = lowerBound(key)
        guard index < starts.count, compare(keyAt: index, to: key) == .orderedSame else {
            return []
        }
        return values(at: index)
    }

    func lowerBound(_ target: String) -> Int {
        var low = 0
        var high = starts.count
        while low < high {
            let mid = (low + high) / 2
            if compare(keyAt: mid, to: target) == .orderedAscending {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    func key(at index: Int) -> Substring {
        let line = line(at: index)
        if let tab = line.firstIndex(of: "\t") {
            return line[..<tab]
        }
        return line
    }

    func values(at index: Int) -> [String] {
        let line = line(at: index)
        var parts = line.split(separator: "\t", omittingEmptySubsequences: true)
        guard !parts.isEmpty else { return [] }
        parts.removeFirst()
        return parts.map(String.init)
    }

    private func line(at index: Int) -> Substring {
        let start = starts[index]
        let end = index + 1 < starts.count ? starts[index + 1] : text.endIndex
        var lineEnd = end
        if lineEnd > start, text[text.index(before: lineEnd)] == "\n" {
            lineEnd = text.index(before: lineEnd)
        }
        return text[start..<lineEnd]
    }

    /// Python の str 順（コードポイント順）と揃える。localized compare は使わない。
    private func compare(keyAt index: Int, to target: String) -> ComparisonResult {
        let key = key(at: index)
        let left = key.unicodeScalars
        let right = target.unicodeScalars
        var i = left.startIndex
        var j = right.startIndex
        while i < left.endIndex, j < right.endIndex {
            let a = left[i].value
            let b = right[j].value
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
            i = left.index(after: i)
            j = right.index(after: j)
        }
        if i == left.endIndex, j == right.endIndex { return .orderedSame }
        return i == left.endIndex ? .orderedAscending : .orderedDescending
    }
}

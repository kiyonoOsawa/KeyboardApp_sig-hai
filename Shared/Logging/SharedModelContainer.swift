//
//  SharedModelContainer.swift
//  sb_26sp_app
//

import Foundation
import SwiftData

enum SharedModelContainer {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([KeyInputLog.self, SentenceInputLog.self])
        guard let storeURL = AppGroup.storeURL else {
            throw SharedModelContainerError.appGroupUnavailable
        }
        let configuration = ModelConfiguration(url: storeURL)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static let shared: ModelContainer = {
        do {
            return try makeContainer()
        } catch {
            fatalError("SwiftDataコンテナの初期化に失敗: \(error)")
        }
    }()
}

enum SharedModelContainerError: Error {
    case appGroupUnavailable
}

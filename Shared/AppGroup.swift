//
//  AppGroup.swift
//  sb_26sp_app
//

import Foundation

enum AppGroup {
    static let identifier = "group.com.kiyono.sb-26sp-app"
    static let storeFileName = "InputLogs.store"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var storeURL: URL? {
        containerURL?.appendingPathComponent(storeFileName)
    }
}

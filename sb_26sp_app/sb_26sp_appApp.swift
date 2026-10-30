//
//  sb_26sp_appApp.swift
//  sb_26sp_app
//
//  Created by 大澤清乃 on 2026/06/11.
//

import SwiftUI
import SwiftData

@main
struct sb_26sp_appApp: App {
    init() {
        // キーボードが保存と同時に分析できるよう、モデルを App Group に配置
        SentimentResourceInstaller.installIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

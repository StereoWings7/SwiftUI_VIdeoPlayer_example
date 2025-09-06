//
//  VideoPlayerApp.swift
//  VideoPlayer
//
//  Created by Chika Yamamoto on 2025/08/23.
//

import SwiftData
import SwiftUI

@main
struct VideoPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [VideoMetadata.self, Playlist.self]) { result in
            switch result {
            case .success(let container):
                // 開発環境ではCloudKit同期を無効化
                // 本格的な運用時は以下のコメントを外してCloudKit同期を有効化
                // container.mainContext.cloudKitDatabase = .private("iCloud.com.yourapp.videoplayer")
                print("SwiftData container configured successfully")
            case .failure(let error):
                print("Failed to configure model container: \(error)")
            }
        }
    }
}

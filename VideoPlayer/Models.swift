//
//  Models.swift
//  VideoPlayer
//
//  Created by Chika Yamamoto on 2025/09/06.
//

import Foundation
import SwiftData

@Model
class VideoMetadata {
    @Attribute(.unique) var assetIdentifier: String
    var title: String
    var isFavorite: Bool
    var lastPlayedAt: Date?
    var playbackPosition: TimeInterval
    var tags: [String]
    var userRating: Int  // 1-5 stars
    var duration: TimeInterval
    
    // リレーション
    @Relationship(deleteRule: .nullify, inverse: \Playlist.videoMetadata)
    var playlists: [Playlist] = []
    
    init(assetIdentifier: String, title: String, duration: TimeInterval = 0) {
        self.assetIdentifier = assetIdentifier
        self.title = title
        self.isFavorite = false
        self.lastPlayedAt = nil
        self.playbackPosition = 0
        self.tags = []
        self.userRating = 0
        self.duration = duration
        self.playlists = []
    }
    
    // 再生進捗率を計算
    var playbackProgress: Double {
        guard duration > 0 else { return 0 }
        return playbackPosition / duration
    }
    
    // 再生時間の文字列表現
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // 最後の再生位置の文字列表現
    var formattedPosition: String {
        let minutes = Int(playbackPosition) / 60
        let seconds = Int(playbackPosition) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@Model
class Playlist {
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var videoCount: Int
    
    @Relationship(deleteRule: .nullify)
    var videoMetadata: [VideoMetadata] = []
    
    init(name: String) {
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.videoCount = 0
    }
    
    // プレイリストに動画を追加
    func addVideo(_ video: VideoMetadata) {
        if !videoMetadata.contains(where: { $0.assetIdentifier == video.assetIdentifier }) {
            videoMetadata.append(video)
            videoCount = videoMetadata.count
            updatedAt = Date()
        }
    }
    
    // プレイリストから動画を削除
    func removeVideo(_ video: VideoMetadata) {
        videoMetadata.removeAll { $0.assetIdentifier == video.assetIdentifier }
        videoCount = videoMetadata.count
        updatedAt = Date()
    }
    
    // 総再生時間を計算
    var totalDuration: TimeInterval {
        videoMetadata.reduce(0) { $0 + $1.duration }
    }
    
    // 総再生時間の文字列表現
    var formattedTotalDuration: String {
        let minutes = Int(totalDuration) / 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

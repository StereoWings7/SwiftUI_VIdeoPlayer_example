//
//  ContentView.swift
//  VideoPlayer
//
//  Created by Chika Yamamoto on 2025/08/23.
//

import AVKit
import PhotosUI
import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var videoMetadata: [VideoMetadata]
    @Query private var playlists: [Playlist]
    
    @State private var selectedItem: PhotosPickerItem?
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var showingVideoPicker = false
    @State private var currentVideoMetadata: VideoMetadata?
    @State private var showingPlaylistView = false
    @State private var showingHistoryView = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Video Player
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(width: 320, height: 180)
                        .cornerRadius(10)
                    
                    // Video Info and Controls
                    if let metadata = currentVideoMetadata {
                        VStack(spacing: 10) {
                            Text(metadata.title)
                                .font(.headline)
                                .lineLimit(2)
                            
                            HStack {
                                // お気に入りボタン
                                Button {
                                    toggleFavorite(metadata)
                                } label: {
                                    Image(systemName: metadata.isFavorite ? "heart.fill" : "heart")
                                        .foregroundColor(metadata.isFavorite ? .red : .gray)
                                        .font(.title2)
                                }
                                
                                Spacer()
                                
                                // プレイリストに追加ボタン
                                Button {
                                    showingPlaylistView = true
                                } label: {
                                    Image(systemName: "plus.circle")
                                        .font(.title2)
                                }
                                .sheet(isPresented: $showingPlaylistView) {
                                    AddToPlaylistView(videoMetadata: metadata)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Play/Pause Button
                    Button {
                        if isPlaying {
                            player.pause()
                            updatePlaybackPosition()
                        } else {
                            player.play()
                        }
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    
                    // Reset Button
                    Button("Reset to Beginning") {
                        player.seek(to: .zero)
                        if let metadata = currentVideoMetadata {
                            metadata.playbackPosition = 0
                            try? modelContext.save()
                        }
                        if isPlaying {
                            player.play()
                        }
                    }
                    .padding()
                    
                } else {
                    // Placeholder when no video is selected
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 320, height: 180)
                        .overlay(
                            Text("No video selected")
                                .foregroundColor(.gray)
                        )
                }
                
                // Pick Video Button
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .videos
                ) {
                    Text("Select Video from Camera Roll")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                // Navigation Buttons
                HStack(spacing: 20) {
                    Button("View History") {
                        showingHistoryView = true
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    NavigationLink("Manage Playlists") {
                        PlaylistManagementView()
                    }
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .navigationTitle("Video Player")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                await loadVideo(from: newItem)
            }
        }
        .onAppear {
            // 定期的に再生位置を更新
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                if isPlaying {
                    updatePlaybackPosition()
                }
            }
        }
        .sheet(isPresented: $showingHistoryView) {
            VideoHistoryView()
        }
    }
    
    @MainActor
    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            // Get the movie file from the selected item
            if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
                // Stop current player if playing
                player?.pause()
                isPlaying = false
                
                // Create new player with selected video
                player = AVPlayer(url: movie.url)
                
                // Get or create video metadata
                await createOrUpdateVideoMetadata(from: item, url: movie.url)
                
                // Restore playback position if available
                if let metadata = currentVideoMetadata, metadata.playbackPosition > 0 {
                    let time = CMTime(seconds: metadata.playbackPosition, preferredTimescale: 600)
                    await player?.seek(to: time)
                }
                
                // Optional: Add observer to know when video ends
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player?.currentItem,
                    queue: .main
                ) { _ in
                    isPlaying = false
                    player?.seek(to: .zero)
                    if let metadata = currentVideoMetadata {
                        metadata.playbackPosition = 0
                        try? modelContext.save()
                    }
                }
            }
        } catch {
            print("Failed to load video: \(error)")
        }
    }
    
    private func createOrUpdateVideoMetadata(from item: PhotosPickerItem, url: URL) async {
        // PhotosPickerから識別子を取得（簡易実装）
        let identifier = url.lastPathComponent
        
        // 既存のメタデータを検索
        if let existing = videoMetadata.first(where: { $0.assetIdentifier == identifier }) {
            existing.lastPlayedAt = Date()
            currentVideoMetadata = existing
        } else {
            // 新しいメタデータを作成
            let asset = AVURLAsset(url: url)
            let duration = try? await asset.load(.duration)
            let durationSeconds = duration?.seconds ?? 0
            
            let metadata = VideoMetadata(
                assetIdentifier: identifier,
                title: url.deletingPathExtension().lastPathComponent,
                duration: durationSeconds
            )
            metadata.lastPlayedAt = Date()
            
            modelContext.insert(metadata)
            currentVideoMetadata = metadata
        }
        
        try? modelContext.save()
    }
    
    private func toggleFavorite(_ metadata: VideoMetadata) {
        metadata.isFavorite.toggle()
        try? modelContext.save()
    }
    
    private func updatePlaybackPosition() {
        guard let player = player,
              let metadata = currentVideoMetadata
        else { return }
        
        let currentTime = player.currentTime().seconds
        if !currentTime.isNaN && currentTime > 0 {
            metadata.playbackPosition = currentTime
            metadata.lastPlayedAt = Date()
            try? modelContext.save()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [VideoMetadata.self, Playlist.self])
}

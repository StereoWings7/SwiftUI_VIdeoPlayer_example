//
//  VideoHistoryView.swift
//  VideoPlayer
//
//  Created by Chika Yamamoto on 2025/09/06.
//

import SwiftData
import SwiftUI

struct VideoHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var videoMetadata: [VideoMetadata]

    var recentlyPlayedVideos: [VideoMetadata] {
        videoMetadata
            .filter { $0.lastPlayedAt != nil }
            .sorted {
                ($0.lastPlayedAt ?? Date.distantPast) > ($1.lastPlayedAt ?? Date.distantPast)
            }
    }

    var favoriteVideos: [VideoMetadata] {
        videoMetadata
            .filter { $0.isFavorite }
            .sorted {
                ($0.lastPlayedAt ?? Date.distantPast) > ($1.lastPlayedAt ?? Date.distantPast)
            }
    }

    var body: some View {
        NavigationStack {
            List {
                if !favoriteVideos.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteVideos) { video in
                            VideoHistoryRowView(video: video) {
                                toggleFavorite(video)
                            }
                        }
                    }
                }

                if !recentlyPlayedVideos.isEmpty {
                    Section("Recently Played") {
                        ForEach(recentlyPlayedVideos) { video in
                            VideoHistoryRowView(video: video) {
                                toggleFavorite(video)
                            }
                        }
                        .onDelete(perform: deleteFromHistory)
                    }
                } else {
                    Section {
                        Text("No videos in history")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .navigationTitle("Video History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !recentlyPlayedVideos.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            clearAllHistory()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }

    private func toggleFavorite(_ video: VideoMetadata) {
        video.isFavorite.toggle()
        try? modelContext.save()
    }

    private func deleteFromHistory(offsets: IndexSet) {
        for index in offsets {
            let video = recentlyPlayedVideos[index]
            modelContext.delete(video)
        }
        try? modelContext.save()
    }

    private func clearAllHistory() {
        for video in videoMetadata {
            modelContext.delete(video)
        }
        try? modelContext.save()
    }
}

struct VideoHistoryRowView: View {
    let video: VideoMetadata
    let onFavoriteToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Text(video.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if video.playbackPosition > 0 {
                        Text("• \(video.formattedPosition)")
                            .font(.caption)
                            .foregroundColor(.blue)

                        // 進捗バー
                        ProgressView(value: video.playbackProgress)
                            .frame(width: 50)
                            .scaleEffect(0.8)
                    }

                    Spacer()
                }

                if let lastPlayed = video.lastPlayedAt {
                    Text("Played \(lastPlayed, style: .relative)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                onFavoriteToggle()
            } label: {
                Image(systemName: video.isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(video.isFavorite ? .red : .gray)
                    .font(.title2)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VideoMetadata.self, Playlist.self, configurations: config)

    let sampleVideo1 = VideoMetadata(
        assetIdentifier: "sample1", title: "Sample Video 1", duration: 120)
    sampleVideo1.lastPlayedAt = Date()
    sampleVideo1.playbackPosition = 60
    sampleVideo1.isFavorite = true

    let sampleVideo2 = VideoMetadata(
        assetIdentifier: "sample2", title: "Sample Video 2", duration: 180)
    sampleVideo2.lastPlayedAt = Date().addingTimeInterval(-3600)

    container.mainContext.insert(sampleVideo1)
    container.mainContext.insert(sampleVideo2)

    return VideoHistoryView()
        .modelContainer(container)
}

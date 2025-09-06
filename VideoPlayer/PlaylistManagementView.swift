//
//  PlaylistManagementView.swift
//  VideoPlayer
//
//  Created by Chika Yamamoto on 2025/09/06.
//

import SwiftData
import SwiftUI

struct PlaylistManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(playlists.sorted(by: { $0.updatedAt > $1.updatedAt })) { playlist in
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist)) {
                        PlaylistRowView(playlist: playlist)
                    }
                }
                .onDelete(perform: deletePlaylists)
            }
            .navigationTitle("Playlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreatePlaylist = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreatePlaylist) {
                CreatePlaylistView()
            }
        }
    }

    private func deletePlaylists(offsets: IndexSet) {
        let sortedPlaylists = playlists.sorted(by: { $0.updatedAt > $1.updatedAt })
        for index in offsets {
            modelContext.delete(sortedPlaylists[index])
        }
        try? modelContext.save()
    }
}

struct PlaylistRowView: View {
    let playlist: Playlist

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(playlist.name)
                .font(.headline)

            HStack {
                Text("\(playlist.videoCount) videos")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(playlist.formattedTotalDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Updated: \(playlist.updatedAt, style: .relative)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct CreatePlaylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var playlistName = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Playlist Details") {
                    TextField("Playlist Name", text: $playlistName)
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createPlaylist()
                    }
                    .disabled(playlistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func createPlaylist() {
        let trimmedName = playlistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newPlaylist = Playlist(name: trimmedName)
        modelContext.insert(newPlaylist)

        try? modelContext.save()
        dismiss()
    }
}

struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let playlist: Playlist

    @State private var showingEditName = false
    @State private var editedName = ""

    var body: some View {
        List {
            Section {
                ForEach(
                    playlist.videoMetadata.sorted(by: {
                        ($0.lastPlayedAt ?? Date.distantPast)
                            > ($1.lastPlayedAt ?? Date.distantPast)
                    })
                ) { video in
                    VideoMetadataRowView(video: video) {
                        removeVideo(video)
                    }
                }
                .onDelete(perform: deleteVideos)
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Videos (\(playlist.videoCount))")
                        Spacer()
                        Text(playlist.formattedTotalDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    editedName = playlist.name
                    showingEditName = true
                }
            }
        }
        .alert("Edit Playlist Name", isPresented: $showingEditName) {
            TextField("Playlist Name", text: $editedName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveEditedName()
            }
        }
    }

    private func deleteVideos(offsets: IndexSet) {
        let sortedVideos = playlist.videoMetadata.sorted(by: {
            ($0.lastPlayedAt ?? Date.distantPast) > ($1.lastPlayedAt ?? Date.distantPast)
        })
        for index in offsets {
            removeVideo(sortedVideos[index])
        }
    }

    private func removeVideo(_ video: VideoMetadata) {
        playlist.removeVideo(video)
        try? modelContext.save()
    }

    private func saveEditedName() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            playlist.name = trimmedName
            playlist.updatedAt = Date()
            try? modelContext.save()
        }
    }
}

struct VideoMetadataRowView: View {
    let video: VideoMetadata
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    if video.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Text(video.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if video.playbackPosition > 0 {
                        Text("• \(video.formattedPosition)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    if let lastPlayed = video.lastPlayedAt {
                        Text(lastPlayed, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            Button("Remove") {
                onRemove()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    PlaylistManagementView()
}

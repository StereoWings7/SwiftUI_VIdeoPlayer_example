//
//  AddToPlaylistView.swift
//  VideoPlayer
//
//  Created by Chika Yamamoto on 2025/09/06.
//

import SwiftData
import SwiftUI

struct AddToPlaylistView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var playlists: [Playlist]

    let videoMetadata: VideoMetadata
    @State private var selectedPlaylists: Set<Playlist> = []
    @State private var showingCreatePlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            List {
                if playlists.isEmpty {
                    Section {
                        Text("No playlists available")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                } else {
                    Section("Select Playlists") {
                        ForEach(playlists.sorted(by: { $0.name < $1.name })) { playlist in
                            PlaylistSelectionRow(
                                playlist: playlist,
                                isSelected: selectedPlaylists.contains(playlist)
                                    || playlist.videoMetadata.contains(where: {
                                        $0.assetIdentifier == videoMetadata.assetIdentifier
                                    }),
                                isAlreadyAdded: playlist.videoMetadata.contains(where: {
                                    $0.assetIdentifier == videoMetadata.assetIdentifier
                                })
                            ) { isSelected in
                                if isSelected {
                                    selectedPlaylists.insert(playlist)
                                } else {
                                    selectedPlaylists.remove(playlist)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingCreatePlaylist = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Create New Playlist")
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        addToSelectedPlaylists()
                        dismiss()
                    }
                    .disabled(selectedPlaylists.isEmpty)
                }
            }
            .alert("Create New Playlist", isPresented: $showingCreatePlaylist) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {
                    newPlaylistName = ""
                }
                Button("Create") {
                    createNewPlaylist()
                }
            } message: {
                Text("Enter a name for the new playlist")
            }
        }
        .onAppear {
            // 既に追加されているプレイリストを選択状態にする
            selectedPlaylists = Set(
                playlists.filter { playlist in
                    playlist.videoMetadata.contains(where: {
                        $0.assetIdentifier == videoMetadata.assetIdentifier
                    })
                })
        }
    }

    private func addToSelectedPlaylists() {
        for playlist in selectedPlaylists {
            playlist.addVideo(videoMetadata)
        }

        // 選択から外されたプレイリストからは削除
        for playlist in playlists {
            if !selectedPlaylists.contains(playlist)
                && playlist.videoMetadata.contains(where: {
                    $0.assetIdentifier == videoMetadata.assetIdentifier
                })
            {
                playlist.removeVideo(videoMetadata)
            }
        }

        try? modelContext.save()
    }

    private func createNewPlaylist() {
        let trimmedName = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newPlaylist = Playlist(name: trimmedName)
        newPlaylist.addVideo(videoMetadata)

        modelContext.insert(newPlaylist)
        selectedPlaylists.insert(newPlaylist)

        try? modelContext.save()
        newPlaylistName = ""
    }
}

struct PlaylistSelectionRow: View {
    let playlist: Playlist
    let isSelected: Bool
    let isAlreadyAdded: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Button {
                onToggle(!isSelected)
            } label: {
                HStack {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .blue : .gray)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlist.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack {
                            Text("\(playlist.videoCount) videos")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if isAlreadyAdded {
                                Text("• Already added")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: VideoMetadata.self, Playlist.self, configurations: config)

    let sampleVideo = VideoMetadata(assetIdentifier: "sample", title: "Sample Video")
    container.mainContext.insert(sampleVideo)

    return AddToPlaylistView(videoMetadata: sampleVideo)
        .modelContainer(container)
}

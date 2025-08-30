//
//  ContentView.swift
//  VideoPlayer
//
//  Created by Chika Yamamoto on 2025/08/23.
//

import SwiftUI
import AVKit
import PhotosUI

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var showingVideoPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Video Player
            if let player = player {
                VideoPlayer(player: player)
                    .frame(width: 320, height: 180)
                    .cornerRadius(10)
                
                // Play/Pause Button
                Button {
                    if isPlaying {
                        player.pause()
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
        }
        .padding()
        .onChange(of: selectedItem) { _, newItem in
            Task {
                await loadVideo(from: newItem)
            }
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
                
                // Optional: Add observer to know when video ends
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemDidPlayToEndTime,
                    object: player?.currentItem,
                    queue: .main
                ) { _ in
                    isPlaying = false
                    player?.seek(to: .zero)
                }
            }
        } catch {
            print("Failed to load video: \(error)")
        }
    }
}

// Custom transferable type for video
struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            // Copy the file to a temporary location
            let fileName = received.file.lastPathComponent
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return VideoTransferable(url: tempURL)
        }
    }
}

#Preview {
    ContentView()
}

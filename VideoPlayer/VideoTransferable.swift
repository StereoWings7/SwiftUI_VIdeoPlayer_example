//
//  VideoTransferable.swift
//  VideoPlayer
//
//  Created by Chika Yamamoto on 2025/09/06.
//

import CoreTransferable
import Foundation
import UniformTypeIdentifiers

// Custom transferable type for video
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            // エクスポート時の処理
            SentTransferredFile(video.url)
        } importing: { received in
            // インポート時の処理
            let fileName = received.file.lastPathComponent
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            // 既存ファイルがある場合は削除
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            // ファイルを一時ディレクトリにコピー
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return VideoTransferable(url: tempURL)
        }
    }
}

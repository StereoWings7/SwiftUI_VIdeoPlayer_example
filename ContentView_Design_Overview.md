# ContentView.swift 設計と技術概要

## プロジェクト概要
このファイルは、SwiftUIを使用したビデオプレイヤーアプリのメインビューを実装しています。ユーザーがフォトライブラリからビデオを選択し、再生制御できる機能を提供します。

## アーキテクチャ設計

### 1. MVVMパターンの部分実装
- **View**: `ContentView` - UI表示とユーザーインタラクション
- **Model**: `VideoTransferable` - データ転送ロジック
- **ViewModel**: 状態管理は@Stateプロパティで実装

### 2. 責任分離
- **UI表示**: ContentViewが担当
- **データ転送**: VideoTransferableが担当
- **メディア再生**: AVPlayerが担当

## 主要コンポーネント

### ContentView構造体
```swift
struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var showingVideoPicker = false
}
```

#### 状態管理プロパティ
- `selectedItem`: 選択されたフォトアイテム
- `player`: AVPlayerインスタンス（ビデオ再生用）
- `isPlaying`: 再生状態フラグ
- `showingVideoPicker`: ビデオピッカー表示状態

### UI構成
1. **ビデオプレイヤー部分**: VideoPlayer（AVKit）を使用
2. **制御ボタン**: 再生/一時停止、リセット
3. **ビデオ選択**: PhotosPicker（PhotosUI）を使用

## 利用技術の詳細解説

### @MainActor
([SwiftのActorを使って安全な並行処理を実装しよう](https://zenn.dev/hsylife/articles/cabbe988c648a0)も参照のこと)

#### 概要
`@MainActor`は、Swift 5.5で導入されたActor型の特殊な形で、UIスレッド（メインスレッド）での実行を保証する属性です。

#### 特徴
- **UI安全性**: UIの更新は必ずメインスレッドで実行される必要がある
- **自動同期**: 非同期コードでもメインスレッドでの実行を保証
- **データ競合防止**: Actor機能により、データ競合を防ぐ

#### コード例での使用
```swift
@MainActor
private func loadVideo(from item: PhotosPickerItem?) async {
    // このメソッド内のコードは全てメインスレッドで実行される
    player = AVPlayer(url: movie.url)  // UI更新が安全
}
```

#### なぜ必要？
- `AVPlayer`の状態変更はUI更新を伴うため
- `@State`プロパティの更新はメインスレッドで行う必要があるため
- 非同期処理からの安全なUI更新のため

### Transferableプロトコル について

#### 概要
iOS 16で導入されたプロトコルで、データの転送・変換方法を定義します。ドラッグ&ドロップ、クリップボード、PhotosPickerなどで使用されます。

#### 特徴
- **型安全**: 転送データの型を明確に定義
- **柔軟性**: 様々なデータ形式に対応
- **統一API**: 異なる転送手段で同じインターフェース

#### VideoTransferableの実装
```swift
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            // エクスポート時の処理
            SentTransferredFile(video.url)
        } importing: { received in
            // インポート時の処理
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(received.file.lastPathComponent)

            // ファイルを一時ディレクトリにコピー
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return VideoTransferable(url: tempURL)
        }
    }
}
```

**機能解説**: このコードは、PhotosPickerから選択されたビデオファイルを安全にアプリ内で使用可能にするためのブリッジ機能を実現しています。主な機能は：

1. **セキュリティ境界の処理**: フォトライブラリの保護されたファイルをアプリのサンドボックス内にコピー
2. **AVPlayer対応**: 一時ディレクトリに配置することで、AVPlayerが読み取り可能なURLを提供
3. **ファイル管理**: 同名ファイルの重複を防ぐために既存ファイルを削除してから新しいファイルをコピー
4. **型安全性**: Transferableプロトコルにより、コンパイル時にデータ型の整合性を保証

#### 処理フロー
1. **ファイル受信**: PhotosPickerからファイルを受け取る
2. **一時保存**: アプリの一時ディレクトリにコピー
3. **URL生成**: AVPlayerで再生可能なURLを提供
4. **重複処理**: 既存ファイルがあれば削除してから保存

## SwiftUI特有の技術

### 1. 状態駆動UI
```swift
.onChange(of: selectedItem) { _, newItem in
    Task {
        await loadVideo(from: newItem)
    }
}
```
- 状態変化に基づくUI更新
- 宣言的プログラミングパラダイム

### 2. View修飾子チェーン
```swift
VideoPlayer(player: player)
    .frame(width: 320, height: 180)
    .cornerRadius(10)
```
- メソッドチェーンによるスタイリング
- 可読性の高いUI構築

### 3. Binding
- `$selectedItem`: PhotosPickerとの双方向データバインディング
- リアクティブプログラミングの実現

## 非同期処理とエラーハンドリング

### async/await パターン
```swift
Task {
    await loadVideo(from: newItem)
}
```
- Modern Concurrencyによる非同期処理
- コールバック地獄の回避

### エラーハンドリング
```swift
do {
    if let movie = try await item.loadTransferable(type: VideoTransferable.self) {
        // 成功処理
    }
} catch {
    print("Failed to load video: \(error)")
}
```
- do-catch文による例外処理
- ユーザーフレンドリーなエラー対応

## 設計上の利点

### 1. 保守性
- 責任が明確に分離されている
- 各コンポーネントが独立している

### 2. 拡張性
- Transferableプロトコルにより、他のデータ形式に容易に対応可能
- 状態管理が一元化されている

### 3. 安全性
- @MainActorによるスレッド安全性
- 型安全なデータ転送

### 4. パフォーマンス
- 一時ファイルの適切な管理
- メモリ効率的な非同期処理

## 今後の改善点

### 短期的な改善
1. **エラーUI**: ユーザーに分かりやすいエラー表示
2. **進捗表示**: 大容量ファイル読み込み時の進捗バー
3. **ファイル管理**: 一時ファイルのクリーンアップ処理
4. **アクセシビリティ**: VoiceOverサポートの追加

### 長期的なロードマップ

#### データ管理の高度化
現在はシンプルなビデオ再生機能のみですが、将来的には以下の機能拡張を予定しています：

**メタデータ管理システム**
- **データソース**: PhotoKit経由でメディアファイルにアクセス
- **メタデータ**: SwiftDataによる永続化でアプリ独自データを管理
  - 再生履歴
  - お気に入りマーク
  - カスタムプレイリスト
  - 再生位置の記憶
  - ユーザー評価・タグ

## SwiftDataについて

### 概要
SwiftDataは、iOS 17で導入されたApple公式のデータ永続化フレームワークです。Core Dataの後継として、よりモダンで使いやすいAPIを提供します。

### 特徴
- **宣言的**: SwiftUIとの自然な統合
- **型安全**: Swift言語の型システムを活用
- **マクロベース**: `@Model`マクロによる簡潔な定義
- **CloudKit連携**: iCloud同期の簡単な実装

### ビデオアプリでの実装例

#### 1. データモデル定義
```swift
import SwiftData
import Foundation

@Model
class VideoMetadata {
    @Attribute(.unique) var assetIdentifier: String
    var title: String
    var isFavorite: Bool
    var lastPlayedAt: Date?
    var playbackPosition: TimeInterval
    var tags: [String]
    var userRating: Int // 1-5 stars

    // リレーション
    var playlists: [Playlist]

    init(assetIdentifier: String, title: String) {
        self.assetIdentifier = assetIdentifier
        self.title = title
        self.isFavorite = false
        self.lastPlayedAt = nil
        self.playbackPosition = 0
        self.tags = []
        self.userRating = 0
        self.playlists = []
    }
}

@Model
class Playlist {
    var name: String
    var createdAt: Date
    var videoMetadata: [VideoMetadata]

    init(name: String) {
        self.name = name
        self.createdAt = Date()
        self.videoMetadata = []
    }
}
```

**機能解説**: このデータモデルは、ビデオプレイヤーアプリの高度なメタデータ管理システムを実現しています：

1. **ユニーク識別**: `@Attribute(.unique)`により、PHAssetの`localIdentifier`と1:1で対応し、重複データを防止
2. **視聴履歴追跡**: `lastPlayedAt`と`playbackPosition`で、ユーザーがどの動画をいつ、どこまで視聴したかを記録
3. **パーソナライゼーション**: `isFavorite`、`tags`、`userRating`でユーザーの好みとコンテンツ分類を管理
4. **プレイリスト機能**: 多対多のリレーションシップにより、1つの動画が複数のプレイリストに属することを可能にする
5. **データ永続化**: SwiftDataの`@Model`マクロにより、Core Dataの複雑さを排除しながら強力な永続化機能を提供

#### 2. SwiftUIでの使用
```swift
import SwiftUI
import SwiftData

@main
struct VideoPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [VideoMetadata.self, Playlist.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var videoMetadata: [VideoMetadata]
    @Query private var playlists: [Playlist]

    @State private var selectedVideo: PHAsset?

    var body: some View {
        NavigationStack {
            VStack {
                // 既存のビデオプレイヤーUI

                // お気に入り機能
                if let video = selectedVideo,
                   let metadata = getMetadata(for: video) {
                    Button {
                        toggleFavorite(metadata)
                    } label: {
                        Image(systemName: metadata.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(metadata.isFavorite ? .red : .gray)
                    }
                }

                // 履歴表示
                List(videoMetadata.sorted(by: { $0.lastPlayedAt ?? Date.distantPast > $1.lastPlayedAt ?? Date.distantPast })) { metadata in
                    VideoHistoryRow(metadata: metadata)
                }
            }
        }
    }

    private func getMetadata(for asset: PHAsset) -> VideoMetadata? {
        videoMetadata.first { $0.assetIdentifier == asset.localIdentifier }
    }

    private func toggleFavorite(_ metadata: VideoMetadata) {
        metadata.isFavorite.toggle()
        try? modelContext.save()
    }

    private func updatePlaybackPosition(_ position: TimeInterval, for asset: PHAsset) {
        let metadata = getMetadata(for: asset) ?? VideoMetadata(
            assetIdentifier: asset.localIdentifier,
            title: "Unknown Video"
        )

        if modelContext.model(for: metadata.persistentModelID) == nil {
            modelContext.insert(metadata)
        }

        metadata.playbackPosition = position
        metadata.lastPlayedAt = Date()

        try? modelContext.save()
    }
}
```

**機能解説**: このSwiftUIコードは、データベースとUIの緊密な統合によるリアクティブなビデオ管理アプリを実現しています：

1. **データ注入**: `@Environment(\.modelContext)`でSwiftDataコンテキストをビュー階層全体で共有
2. **リアクティブクエリ**: `@Query`により、データベースの変更が自動的にUIに反映される
3. **インタラクティブ機能**: お気に入りボタンで即座にデータベースを更新し、UIに反映
4. **自動履歴管理**: `updatePlaybackPosition`で再生時に自動的にメタデータを更新・保存
5. **スマート履歴表示**: 最近再生した動画を上位に表示するソート機能
6. **データ整合性**: 新しい動画の場合は自動的にメタデータエントリを作成し、既存の場合は更新

#### 3. CloudKit同期の実装
```swift
// アプリエントリーポイントで設定
.modelContainer(for: [VideoMetadata.self, Playlist.self]) { result in
    switch result {
    case .success(let container):
        // CloudKit同期の有効化
        container.configuration.cloudKitDatabase = .private("iCloud.com.yourapp.videoplayer")
    case .failure(let error):
        print("Failed to configure model container: \(error)")
    }
}
```

**機能解説**: このCloudKit統合コードは、ユーザーのデバイス間でのシームレスなデータ同期を実現しています：

1. **マルチデバイス同期**: iPhone、iPad、Mac間で視聴履歴、お気に入り、プレイリストが自動同期
2. **プライベートデータベース**: `.private`により、各ユーザーのデータは他のユーザーからアクセス不可能で、プライバシーを保護
3. **自動バックアップ**: iCloudによる自動バックアップで、デバイス紛失時もデータが保護される
4. **オフライン対応**: ネットワーク接続がない時もローカルで動作し、接続復帰時に自動同期
5. **競合解決**: 複数デバイスで同時編集された場合のデータ整合性をCloudKitが自動処理
6. **エラーハンドリング**: 設定失敗時の適切なエラー処理により、アプリの安定性を確保

### 実装時の考慮点

#### データ分離
- **PhotoKit**: 実際のメディアファイルへの読み取り専用アクセス
- **SwiftData**: アプリ固有のメタデータ（履歴、お気に入り、プレイリスト）
- **同期**: PHAssetのlocalIdentifierでデータを関連付け

#### パフォーマンス最適化
- 大量の動画データに対応するためのページング実装
- バックグラウンドでのメタデータ更新
- Core Dataと比較して改善されたメモリ効率

#### プライバシー考慮
- ユーザーのメディアライブラリアクセス権限管理
- メタデータの適切な匿名化
- CloudKit使用時のユーザー同意取得

この拡張により、単純なビデオプレイヤーから本格的なメディア管理アプリケーションへと発展させることができます。

このような設計により、現代的なSwiftUIアプリケーションとして、安全で保守性の高いコードが実現されています。

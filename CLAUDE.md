# CLAUDE.md - AI Assistant Guide for SwiftUI VideoPlayer

**Last Updated:** 2025-11-17
**Project:** VideoPlayer (SwiftUI Video Player with Favorites, History, and Playlists)
**Platform:** iOS 18.5+
**Language:** Swift 5.0
**Architecture:** SwiftUI + SwiftData (MVVM)

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Codebase Structure](#codebase-structure)
3. [Architecture & Patterns](#architecture--patterns)
4. [Key Files & Components](#key-files--components)
5. [Data Flow & State Management](#data-flow--state-management)
6. [Features & Functionality](#features--functionality)
7. [Development Workflows](#development-workflows)
8. [Code Conventions](#code-conventions)
9. [Common Tasks & Patterns](#common-tasks--patterns)
10. [Important Constraints](#important-constraints)
11. [Testing Strategy](#testing-strategy)

---

## Project Overview

### What This Project Is

A modern iOS video player application demonstrating SwiftData integration with:
- Video playback from Camera Roll using PhotosPicker
- Favorites system with heart icons
- Watch history with playback position tracking
- Custom playlist creation and management
- Many-to-many relationships (videos ↔ playlists)
- Automatic playback position restoration

### Key Statistics

- **Total Code:** 1,043 lines across 7 Swift files
- **External Dependencies:** None (Apple frameworks only)
- **iOS Target:** 18.5+ (very recent, cutting-edge)
- **Testing:** None (prototype/example project)
- **Comments:** Primarily in Japanese

### Technology Stack

```
SwiftUI (UI framework)
├── SwiftData (persistence)
├── AVKit (video playback)
├── PhotosUI (media selection)
├── CoreTransferable (data transfer)
└── Foundation (core utilities)
```

---

## Codebase Structure

### Directory Layout

```
SwiftUI_VideoPlayer_example/
├── README.md                           # Minimal project description
├── VideoPlayer.xcodeproj/              # Xcode project configuration
│   └── project.pbxproj                 # Build settings and targets
└── VideoPlayer/                        # Main source directory
    ├── VideoPlayerApp.swift            # App entry point (29 lines)
    ├── Models.swift                    # Data models (103 lines)
    ├── ContentView.swift               # Main video player (256 lines)
    ├── VideoHistoryView.swift          # History UI (176 lines)
    ├── PlaylistManagementView.swift    # Playlist CRUD (254 lines)
    ├── AddToPlaylistView.swift         # Add to playlist (190 lines)
    ├── VideoTransferable.swift         # Transfer protocol (35 lines)
    └── Assets.xcassets/                # Images, colors, sample data
```

### File Responsibilities

| File | Primary Responsibility | Key Components |
|------|----------------------|----------------|
| `VideoPlayerApp.swift` | App lifecycle, SwiftData setup | @main, modelContainer config |
| `Models.swift` | Data models | VideoMetadata, Playlist classes |
| `ContentView.swift` | Video playback & controls | AVPlayer, PhotosPicker, position tracking |
| `VideoHistoryView.swift` | History & favorites display | VideoHistoryRowView |
| `PlaylistManagementView.swift` | Playlist management | PlaylistRowView, CreatePlaylistView, PlaylistDetailView |
| `AddToPlaylistView.swift` | Add videos to playlists | PlaylistSelectionRow |
| `VideoTransferable.swift` | PhotosPicker integration | Transferable conformance |

---

## Architecture & Patterns

### MVVM + SwiftData Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    View Layer (SwiftUI)                  │
│  ContentView, VideoHistoryView, PlaylistManagementView  │
│                                                           │
│  @State, @Environment, @Query                            │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Two-way binding
                 │
┌────────────────▼────────────────────────────────────────┐
│              ViewModel (Implicit)                        │
│  SwiftUI Property Wrappers + Computed Properties        │
│  @Query auto-updates, @Environment injects dependencies │
└────────────────┬────────────────────────────────────────┘
                 │
                 │ Data operations
                 │
┌────────────────▼────────────────────────────────────────┐
│              Model Layer (SwiftData)                     │
│         VideoMetadata (@Model)                           │
│         Playlist (@Model)                                │
│                                                           │
│  Persistence: SwiftData + Optional CloudKit             │
└─────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

1. **SwiftData First**: All persistence handled by SwiftData (iOS 17+)
2. **Reactive by Default**: @Query automatically updates views when models change
3. **Environment Injection**: ModelContext injected via @Environment
4. **Composition Pattern**: Small, focused view components composed into larger ones
5. **Single Source of Truth**: SwiftData models are the authoritative data source
6. **No Singletons**: No global state or singleton managers
7. **CloudKit Ready**: Infrastructure present but disabled for development

### Data Model Relationships

```
VideoMetadata ←→ Playlist
    (Many)         (Many)

Delete Rule: .nullify
├── Deleting video: removes from playlists but keeps playlist
└── Deleting playlist: removes relationship but keeps videos
```

---

## Key Files & Components

### 1. VideoPlayerApp.swift

**Location:** `/home/user/SwiftUI_VideoPlayer_example/VideoPlayer/VideoPlayerApp.swift`

**Purpose:** Application entry point and SwiftData configuration

**Key Code:**
```swift
@main
struct VideoPlayerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [VideoMetadata.self, Playlist.self])
    }
}
```

**What AI Assistants Should Know:**
- CloudKit sync is commented out (see line ~15-20)
- Models registered: `VideoMetadata` and `Playlist`
- Uses default model configuration
- No custom container configuration for development

---

### 2. Models.swift

**Location:** `/home/user/SwiftUI_VideoPlayer_example/VideoPlayer/Models.swift`

**Classes Defined:**

#### VideoMetadata (@Model)
```swift
@Model
class VideoMetadata {
    var assetIdentifier: String        // Unique identifier
    var title: String                  // Extracted from filename
    var isFavorite: Bool              // Favorite status
    var lastPlayedAt: Date?           // Last playback timestamp
    var playbackPosition: TimeInterval // Current playback position (seconds)
    var tags: [String]                // Tags (UI not implemented)
    var userRating: Int               // 1-5 stars (UI not implemented)
    var duration: TimeInterval        // Total video duration

    @Relationship(deleteRule: .nullify, inverse: \Playlist.videoMetadata)
    var playlists: [Playlist]         // Many-to-many relationship
}
```

**Computed Properties:**
- `playbackProgress: Double` - Percentage (0.0-1.0)
- `formattedDuration: String` - "M:SS" format
- `formattedPosition: String` - "M:SS" format

#### Playlist (@Model)
```swift
@Model
class Playlist {
    var name: String                   // Playlist name
    var createdAt: Date               // Creation timestamp
    var updatedAt: Date               // Last modification timestamp

    @Relationship(deleteRule: .nullify)
    var videoMetadata: [VideoMetadata] // Many-to-many relationship
}
```

**Stored Properties:**
- `videoCount: Int` - Count of videos (stored property, manually updated in `addVideo(_:)` and `removeVideo(_:)`)

**Methods:**
- `addVideo(_:)` - Adds video if not already present, updates timestamp and videoCount
- `removeVideo(_:)` - Removes video, updates timestamp and videoCount

**Computed Properties:**
- `totalDuration: TimeInterval` - Sum of all video durations
- `formattedTotalDuration: String` - "H:MM:SS" format

**Important Notes:**
- All relationship modifications update `updatedAt`
- Delete rule `.nullify` prevents cascading deletes
- Duration calculations handle edge cases (zero duration)
- `videoCount` is a stored property, not computed; it is updated whenever videos are added or removed from the playlist

---

### 3. ContentView.swift

**Location:** `/home/user/SwiftUI_VideoPlayer_example/VideoPlayer/ContentView.swift`

**Purpose:** Main video player interface with playback controls

**State Variables:**
```swift
@Environment(\.modelContext) private var modelContext
@Query private var videoMetadata: [VideoMetadata]
@State private var selectedItem: PhotosPickerItem?
@State private var player: AVPlayer?
@State private var isPlaying = false
@State private var currentVideoMetadata: VideoMetadata?
@State private var showingPlaylistView = false
@State private var showingHistoryView = false
```

**Key Functions:**

| Function | Purpose | Location (approx) |
|----------|---------|------------------|
| `loadVideo(from:)` | Async load video from PhotosPicker | Line ~165 |
| `createOrUpdateVideoMetadata(for:)` | Create/update metadata with AVAsset | Line ~206 |
| `updatePlaybackPosition()` | Save current playback position | Line ~239 |
| `toggleFavorite()` | Toggle favorite status | Line ~234 |

**Important Patterns:**
```swift
// Playback position restoration
if let position = metadata.playbackPosition, position > 0 {
    player.seek(to: CMTime(seconds: position, preferredTimescale: 600))
}

// Periodic position updates (every 1 second)
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    updatePlaybackPosition()
}

// Error handling pattern
try? modelContext.save()  // Silent failure (no user feedback)
```

**Navigation Structure:**
- PhotosPicker for video selection
- Sheet for AddToPlaylistView
- Sheet for VideoHistoryView
- NavigationStack for hierarchy

---

### 4. VideoHistoryView.swift

**Location:** `/home/user/SwiftUI_VideoPlayer_example/VideoPlayer/VideoHistoryView.swift`

**Components:**
1. **VideoHistoryView**: Main container with favorites and recents sections
2. **VideoHistoryRowView**: Reusable row component with thumbnail placeholder

**Computed Properties:**
```swift
var favoriteVideos: [VideoMetadata] {
    videoMetadata.filter { $0.isFavorite }
        .sorted { $0.lastPlayedAt ?? .distantPast > $1.lastPlayedAt ?? .distantPast }
}

var recentlyPlayedVideos: [VideoMetadata] {
    videoMetadata.filter { $0.lastPlayedAt != nil }
        .sorted { $0.lastPlayedAt! > $1.lastPlayedAt! }
}
```

**Features:**
- Swipe-to-delete for individual videos
- "Clear All History" button
- Progress bars showing watch percentage
- Relative time display ("2 hours ago")
- Favorite toggle in rows

**Important:** Uses `ForEach(videos)` pattern requiring `Identifiable` conformance

---

### 5. PlaylistManagementView.swift

**Location:** `/home/user/SwiftUI_VideoPlayer_example/VideoPlayer/PlaylistManagementView.swift`

**Components:**
1. **PlaylistManagementView**: List of all playlists
2. **PlaylistRowView**: Summary row (name, count, duration)
3. **CreatePlaylistView**: New playlist creation sheet
4. **PlaylistDetailView**: Individual playlist detail with video list
5. **VideoMetadataRowView**: Video row in playlist detail

**Key Functions:**
```swift
createPlaylist(name:)           // Create new playlist
deletePlaylist(_:)              // Delete with cascade
renamePlaylist(_:newName:)      // Update playlist name
removeVideoFromPlaylist(_:)     // Remove video from current playlist
```

**Sorting:**
```swift
var sortedPlaylists: [Playlist] {
    playlists.sorted { $0.updatedAt > $1.updatedAt }
}
```

**Important Notes:**
- Playlists sorted by most recently updated
- Delete confirmation alert for playlists
- Inline rename via alert dialog
- Video count and duration display

---

### 6. AddToPlaylistView.swift

**Location:** `/home/user/SwiftUI_VideoPlayer_example/VideoPlayer/AddToPlaylistView.swift`

**Purpose:** Multi-select interface to add video to playlists

**Components:**
1. **AddToPlaylistView**: Main selection interface
2. **PlaylistSelectionRow**: Checkbox-style row

**State Management:**
```swift
@State private var selectedPlaylists: Set<Playlist>
@State private var showingCreatePlaylist = false
@State private var newPlaylistName = ""

// Initialize with already-selected playlists
init(videoMetadata: VideoMetadata) {
    self.videoMetadata = videoMetadata
    _selectedPlaylists = State(initialValue: Set(videoMetadata.playlists))
}
```

**Save Logic:**
```swift
// Add to selected playlists
for playlist in selectedPlaylists {
    playlist.addVideo(videoMetadata)
}

// Remove from deselected playlists
for playlist in playlists {
    if !selectedPlaylists.contains(playlist)
        && playlist.videoMetadata.contains(where: {
            $0.assetIdentifier == videoMetadata.assetIdentifier
        })
    {
        playlist.removeVideo(videoMetadata)
    }
}
```

**Features:**
- Shows checkmarks for already-added playlists
- Create new playlist inline
- Sync on save (add to selected, remove from deselected)
- Disabled state when no name entered

---

### 7. VideoTransferable.swift

**Location:** `/home/user/SwiftUI_VideoPlayer_example/VideoPlayer/VideoTransferable.swift`

**Purpose:** Conform to `Transferable` protocol for PhotosPicker integration

**Implementation:**
```swift
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self.init(url: copy)
        }
    }
}
```

**What AI Assistants Should Know:**
- Copies video to temporary directory
- Generates unique filename with UUID
- Uses `.movie` content type (all video formats)
- No cleanup logic (iOS handles temp directory)

---

## Data Flow & State Management

### SwiftData Reactive Flow

```
User Action (e.g., toggle favorite)
        ↓
Update model property (metadata.isFavorite.toggle())
        ↓
modelContext.save()
        ↓
SwiftData persistence layer
        ↓
@Query monitoring detects change
        ↓
View automatically re-renders
        ↓
UI updates (heart icon fills/unfills)
```

### Video Selection Flow

```
1. User taps PhotosPicker
2. selectedItem state updated
3. onChange(of: selectedItem) triggered
4. loadVideo() async function executes
5. VideoTransferable loads file to temp directory
6. createOrUpdateVideoMetadata() called
   ├── Check if video already exists (by identifier)
   ├── If exists: update existing metadata
   └── If new: create new VideoMetadata instance
7. AVURLAsset extracts duration
8. modelContext.insert() or update existing
9. modelContext.save()
10. @Query automatically updates
11. UI re-renders with new video
12. AVPlayer created and playback starts
```

### Playback Position Tracking

```
Timer (1 second interval)
        ↓
Check if isPlaying == true
        ↓
Get player.currentTime()
        ↓
Update metadata.playbackPosition
        ↓
Update metadata.lastPlayedAt
        ↓
Save to SwiftData
        ↓
Position persisted
```

**Important:** Timer invalidated when video ends or view disappears

### Relationship Synchronization

```
AddToPlaylistView.save() called
        ↓
For each selected playlist:
    ├── playlist.addVideo(metadata)
    └── Updates playlist.updatedAt
        ↓
For each deselected playlist:
    ├── playlist.removeVideo(metadata)
    └── Updates playlist.updatedAt
        ↓
modelContext.save()
        ↓
Both @Query(for: Playlist) and @Query(for: VideoMetadata) update
        ↓
All views showing either playlists or videos refresh
```

---

## Features & Functionality

### Implemented Features

#### ✅ Core Video Playback
- Video selection from Camera Roll (PhotosPicker)
- AVPlayer-based playback with controls
- Play/pause toggle
- Reset to beginning (seek to 00:00)
- Automatic playback position restoration on reload
- Video end detection (NotificationCenter)

#### ✅ Favorites System
- Toggle favorite status with heart button
- Visual indication (filled ❤️ vs outlined 🤍)
- Red color for favorited videos
- Dedicated favorites section in history view
- Favorites sorted by last played

#### ✅ Watch History
- Automatic tracking with timestamps
- Recently played videos sorted by date
- Playback progress indicator (0-100%)
- Relative time display ("2 hours ago", "Yesterday")
- Swipe-to-delete individual videos
- Clear all history function
- Progress bar visualization

#### ✅ Playlist Management
- Create custom playlists with names
- Add videos to multiple playlists
- Remove videos from playlists
- Edit playlist names (alert-based)
- Delete playlists (with confirmation)
- View playlist details with video list
- Video count per playlist
- Total duration calculation
- Sorting by last updated

#### ✅ Metadata Management
- Title extraction from filename
- Duration calculation (AVURLAsset)
- Playback position tracking (auto-save)
- Unique asset identifier (UUID-based)
- Tags support (data structure only, no UI)
- User rating support (1-5 stars, no UI)

### Partially Implemented Features

#### ⚠️ Tags System
- Data structure: `var tags: [String]` in VideoMetadata
- No UI for adding/editing/displaying tags
- Ready for future implementation

#### ⚠️ User Rating
- Data structure: `var userRating: Int?` (1-5 stars)
- No UI for rating selection/display
- Ready for future implementation

### Not Implemented

#### ❌ CloudKit Sync
- Infrastructure present but commented out
- See VideoPlayerApp.swift for configuration

#### ❌ Video Thumbnails
- Placeholder rectangles used instead
- Could use AVAssetImageGenerator

#### ❌ Search/Filter
- No search functionality
- No filter by tags or rating

#### ❌ Video Editing
- No trim, crop, or editing features

#### ❌ Sharing
- No share sheet integration

#### ❌ Error Handling UI
- Uses `try?` without user feedback
- No error alerts or messages

#### ❌ Loading States
- No loading indicators for async operations
- No progress for video loading

---

## Development Workflows

### Adding a New Feature

1. **Plan with TodoWrite** (if complex, multi-step task)
2. **Identify affected files** (use this CLAUDE.md as reference)
3. **Update models first** (if data structure changes needed)
   - Edit `/home/user/SwiftUI_VideoPlayer_example/VideoPlayer/Models.swift`
   - Add properties, relationships, or methods
   - Consider SwiftData migration implications
4. **Update or create views**
   - Follow naming convention: `[Feature]View.swift`
   - Use @Query for data access
   - Use @Environment(\.modelContext) for writes
5. **Test with Xcode Previews**
   - Add #Preview provider
   - Use in-memory ModelConfiguration for sample data
6. **Update CLAUDE.md** (if significant architectural change)
7. **Commit with descriptive message**
   - Follow git commit conventions
   - Use Japanese or English (project uses both)

### Modifying Existing Features

1. **Locate the responsible file** (see [Key Files & Components](#key-files--components))
2. **Read the entire file** to understand context
3. **Check for related computed properties** (may need updates)
4. **Update all affected views** (search for usages)
5. **Verify @Query dependencies** (check if query predicates need updates)
6. **Test in Xcode** (use simulator or device)
7. **Commit changes**

### Debugging Common Issues

| Issue | Likely Cause | Solution |
|-------|-------------|----------|
| Video doesn't load | PhotosPicker selection failed | Check `loadVideo()` error handling |
| Position not saved | Timer not running | Verify `startPositionUpdateTimer()` called |
| Playlist not updating | Forgot to save context | Add `try? modelContext.save()` |
| View not refreshing | @Query not detecting change | Ensure model property changed and saved |
| Relationship broken | Delete rule incorrect | Check `.nullify` in @Relationship |
| Crash on delete | Force unwrapping nil | Check optional chaining in delete functions |

### Git Workflow

**Current Branch:** `claude/claude-md-mi2qn9ht19u0yh4a-01Ch642jLryRq14uEMyWU87u`

**Important Git Rules:**
1. Always develop on the `claude/` branch specified at conversation start
2. NEVER push to `main` or `master` without explicit permission
3. Use descriptive commit messages (English or Japanese acceptable)
4. Push with `-u origin <branch-name>` for branch creation
5. Retry network failures up to 4 times with exponential backoff (2s, 4s, 8s, 16s)

**Commit Message Style (from history):**
- `feat: SwiftDataによるお気に入り,履歴,プレイリスト機能の実装` (Japanese, descriptive)
- `files cleaned up` (English, concise)
- `private files removed` (English, action-focused)

**Push Command:**
```bash
git push -u origin claude/claude-md-mi2qn9ht19u0yh4a-01Ch642jLryRq14uEMyWU87u
```

---

## Code Conventions

### Naming Conventions

#### Files
- **Views:** `[Component]View.swift` (e.g., `VideoHistoryView.swift`)
- **Models:** `Models.swift` (plural, consolidated)
- **App Entry:** `VideoPlayerApp.swift`
- **Utilities:** `[Type]Transferable.swift`, `[Type]Helper.swift`

#### Types
- **Structs/Classes:** PascalCase (e.g., `VideoMetadata`, `PlaylistRowView`)
- **Protocols:** PascalCase (usually adjectives, e.g., `Transferable`)

#### Variables & Functions
- **Properties:** camelCase (e.g., `lastPlayedAt`, `isFavorite`)
- **Functions:** camelCase with verb prefix (e.g., `toggleFavorite()`, `createPlaylist()`)
- **Private:** Prefix with `private` (e.g., `private var player: AVPlayer?`)

#### Constants
- **State:** `@State private var showingPlaylistView = false`
- **Environment:** `@Environment(\.modelContext) private var modelContext`
- **Query:** `@Query private var videoMetadata: [VideoMetadata]`

### SwiftUI Patterns

#### Property Wrappers (Order Matters)
```swift
// 1. Environment values
@Environment(\.modelContext) private var modelContext
@Environment(\.dismiss) private var dismiss

// 2. Queries
@Query private var videoMetadata: [VideoMetadata]
@Query private var playlists: [Playlist]

// 3. State
@State private var selectedItem: PhotosPickerItem?
@State private var isPlaying = false

// 4. Binding (if applicable)
@Binding var someValue: String
```

#### View Structure
```swift
struct MyView: View {
    // 1. Property wrappers
    @Environment(\.modelContext) private var modelContext
    @State private var showSheet = false

    // 2. Computed properties
    var filteredItems: [Item] {
        items.filter { /* ... */ }
    }

    // 3. Body
    var body: some View {
        NavigationStack {
            // View content
        }
        .toolbar { /* ... */ }
        .sheet(isPresented: $showSheet) { /* ... */ }
    }

    // 4. Helper functions
    private func doSomething() {
        // Implementation
    }
}

// 5. Preview
#Preview {
    MyView()
        .modelContainer(for: [VideoMetadata.self, Playlist.self])
}
```

### SwiftData Patterns

#### Creating Objects
```swift
let video = VideoMetadata(
    assetIdentifier: UUID().uuidString,
    title: title,
    duration: duration
)
modelContext.insert(video)
try? modelContext.save()
```

#### Updating Objects
```swift
// Just modify properties
video.isFavorite.toggle()
video.lastPlayedAt = Date()

// Save context
try? modelContext.save()
```

#### Deleting Objects
```swift
modelContext.delete(video)
try? modelContext.save()
```

#### Querying
```swift
// Simple query
@Query private var videos: [VideoMetadata]

// Sorted query
@Query(sort: \VideoMetadata.lastPlayedAt, order: .reverse)
private var recentVideos: [VideoMetadata]

// Filtered query (use computed property instead)
var favoriteVideos: [VideoMetadata] {
    videos.filter { $0.isFavorite }
}
```

### Error Handling

**Current Pattern:** Silent failure with `try?`
```swift
try? modelContext.save()  // ⚠️ No user feedback on error
```

**Recommended Pattern for Future:**
```swift
do {
    try modelContext.save()
} catch {
    // Show alert to user
    errorMessage = "Failed to save: \(error.localizedDescription)"
    showingError = true
}
```

### Comments

- **Language:** Primarily Japanese, some English
- **Style:** Inline comments for UI elements
- **Examples:**
  ```swift
  // お気に入りボタン (Favorite button)
  Button { toggleFavorite() } // ...

  // 開発環境ではCloudKit同期を無効化 (CloudKit sync disabled in dev)
  // .modelContainer(for: [...], isCloudKitEnabled: true)
  ```

### Time Formatting

**Pattern Used:**
```swift
var formattedDuration: String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%d:%02d", minutes, seconds)
}
```

**For hours:**
```swift
let hours = Int(duration) / 3600
let minutes = Int(duration) % 3600 / 60
let seconds = Int(duration) % 60
return String(format: "%d:%02d:%02d", hours, minutes, seconds)
```

---

## Common Tasks & Patterns

### Task: Add a New Property to VideoMetadata

1. **Update Model:**
   ```swift
   // In Models.swift
   @Model
   class VideoMetadata {
       // ... existing properties ...
       var myNewProperty: String = ""  // Add this
   }
   ```

2. **Consider Migration:**
   - SwiftData may auto-migrate simple additions
   - Complex changes need migration plan
   - Test with existing data

3. **Update Views:**
   - Display in VideoHistoryRowView if needed
   - Add editing UI if user-modifiable
   - Update computed properties if relevant

4. **Update CLAUDE.md:**
   - Document new property in Models section
   - Update any relevant flows

### Task: Add a New View

1. **Create File:**
   ```
   /home/user/SwiftUI_VideoPlayer_example/VideoPlayer/MyFeatureView.swift
   ```

2. **Basic Structure:**
   ```swift
   import SwiftUI
   import SwiftData

   struct MyFeatureView: View {
       @Environment(\.modelContext) private var modelContext
       @Query private var items: [VideoMetadata]

       var body: some View {
           NavigationStack {
               List(items) { item in
                   Text(item.title)
               }
               .navigationTitle("My Feature")
           }
       }
   }

   #Preview {
       MyFeatureView()
           .modelContainer(for: [VideoMetadata.self, Playlist.self])
   }
   ```

3. **Integrate:**
   - Add navigation link in ContentView or VideoHistoryView
   - Or add as sheet presentation
   - Update toolbar items if needed

### Task: Implement Video Thumbnails

**Recommended Approach:**

1. **Add Thumbnail Generation:**
   ```swift
   import AVFoundation

   func generateThumbnail(for url: URL) async -> UIImage? {
       let asset = AVURLAsset(url: url)
       let imageGenerator = AVAssetImageGenerator(asset: asset)
       imageGenerator.appliesPreferredTrackTransform = true

       let time = CMTime(seconds: 1.0, preferredTimescale: 600)

       do {
           let cgImage = try await imageGenerator.image(at: time).image
           return UIImage(cgImage: cgImage)
       } catch {
           return nil
       }
   }
   ```

2. **Store in Model:**
   ```swift
   // Option A: Store as Data
   @Attribute(.externalStorage) var thumbnailData: Data?

   // Option B: Generate on-demand (better for prototype)
   // No storage, generate when needed
   ```

3. **Display in Views:**
   ```swift
   // Replace current rectangles
   if let thumbnailData = video.thumbnailData,
      let uiImage = UIImage(data: thumbnailData) {
       Image(uiImage: uiImage)
           .resizable()
           .scaledToFill()
   } else {
       Rectangle()
           .fill(Color.gray.opacity(0.3))
   }
   ```

### Task: Add Search Functionality

1. **Add Search State:**
   ```swift
   @State private var searchText = ""
   ```

2. **Add Searchable Modifier:**
   ```swift
   .searchable(text: $searchText, prompt: "Search videos")
   ```

3. **Filter Results:**
   ```swift
   var filteredVideos: [VideoMetadata] {
       if searchText.isEmpty {
           return videoMetadata
       }
       return videoMetadata.filter { video in
           video.title.localizedCaseInsensitiveContains(searchText) ||
           video.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
       }
   }
   ```

4. **Use Filtered Results:**
   ```swift
   List(filteredVideos) { video in
       // ...
   }
   ```

### Task: Add Error Handling UI

1. **Add Error State:**
   ```swift
   @State private var errorMessage = ""
   @State private var showingError = false
   ```

2. **Handle Errors:**
   ```swift
   do {
       try modelContext.save()
   } catch {
       errorMessage = "Failed to save: \(error.localizedDescription)"
       showingError = true
   }
   ```

3. **Show Alert:**
   ```swift
   .alert("Error", isPresented: $showingError) {
       Button("OK") { }
   } message: {
       Text(errorMessage)
   }
   ```

### Task: Implement CloudKit Sync

1. **Uncomment in VideoPlayerApp.swift:**
   ```swift
   .modelContainer(
       for: [VideoMetadata.self, Playlist.self],
       isCloudKitEnabled: true
   )
   ```

2. **Add Capabilities in Xcode:**
   - iCloud capability
   - CloudKit container

3. **Handle Conflicts:**
   - Define merge policies
   - Implement conflict resolution

4. **Test:**
   - Sign in with Apple ID
   - Test on multiple devices
   - Verify sync timing

---

## Important Constraints

### Platform Requirements

- **iOS Version:** 18.5+ (very recent, may not be widely available)
- **Xcode:** 16.4+ (required for project format)
- **Swift:** 5.0
- **Frameworks:** SwiftUI, SwiftData (iOS 17+ required)

**Impact for AI Assistants:**
- Code suggestions must be iOS 18.5+ compatible
- Cannot use deprecated APIs from earlier versions
- SwiftData features from iOS 17+ are available
- PhotosUI modern API available

### SwiftData Limitations

1. **No Migration UI:** Schema changes need careful planning
2. **Relationship Complexity:** Many-to-many requires careful delete rule management
3. **CloudKit Sync:** Currently disabled, would need testing
4. **Query Performance:** Large datasets may need optimization
5. **No Full-Text Search:** Must implement custom search

### Architecture Constraints

1. **No UIKit:** Pure SwiftUI (cannot use UIViewController)
2. **No Combine:** Uses async/await and SwiftUI reactive patterns
3. **No Third-Party:** Must use Apple frameworks only
4. **File-Based Sync:** Uses Xcode 16's file system synchronization
5. **Automatic Signing:** Development team SJ55X62654

### Code Quality Issues (For AI to Be Aware Of)

⚠️ **These exist in the current codebase and should be addressed when modifying related code:**

1. **Error Handling:** Extensive use of `try?` without user feedback
   ```swift
   try? modelContext.save()  // Silent failure
   ```

2. **Memory Management:** AVPlayer observers not explicitly removed
   ```swift
   // In ContentView, NotificationCenter observer added but not removed
   ```

3. **Optional Force Unwrapping:** Some cases in filtering
   ```swift
   .sorted { $0.lastPlayedAt! > $1.lastPlayedAt! }  // Could crash if nil
   ```

4. **No Loading States:** Async operations lack progress indicators
   ```swift
   private func loadVideo(from item: PhotosPickerItem?) async {
       // No loading indicator shown to user
   }
   ```

5. **Timer Cleanup:** Timer might not be invalidated in all paths
   ```swift
   positionUpdateTimer?.invalidate()  // Check all code paths
   ```

6. **No Input Validation:** Playlist names, titles not sanitized

7. **Hard-Coded Strings:** No localization (all UI strings hard-coded)

**When Modifying Code:**
- Fix these issues in the area you're working on
- Don't introduce new instances of these patterns
- Prefer explicit error handling over `try?`
- Add loading states for async operations
- Validate user input
- Remove observers in `onDisappear` or deinit

---

## Testing Strategy

### Current State: No Tests

- No unit tests
- No UI tests
- No integration tests
- Preview providers exist (for development, not testing)

### Recommended Testing Approach (If Implementing)

#### 1. Unit Tests for Models

```swift
import XCTest
import SwiftData
@testable import VideoPlayer

final class VideoMetadataTests: XCTestCase {
    var modelContext: ModelContext!

    override func setUp() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: VideoMetadata.self, Playlist.self,
            configurations: config
        )
        modelContext = ModelContext(container)
    }

    func testPlaybackProgress() {
        let video = VideoMetadata(assetIdentifier: "test", title: "Test", duration: 100)
        video.playbackPosition = 50
        XCTAssertEqual(video.playbackProgress, 0.5)
    }

    func testFormattedDuration() {
        let video = VideoMetadata(assetIdentifier: "test", title: "Test", duration: 125)
        XCTAssertEqual(video.formattedDuration, "2:05")
    }
}
```

#### 2. SwiftData Integration Tests

```swift
func testPlaylistAddVideo() {
    let playlist = Playlist(name: "Test Playlist")
    let video = VideoMetadata(assetIdentifier: "test", title: "Test", duration: 100)

    modelContext.insert(playlist)
    modelContext.insert(video)

    playlist.addVideo(video)

    XCTAssertEqual(playlist.videoCount, 1)
    XCTAssertTrue(video.playlists.contains(where: { $0.id == playlist.id }))
}
```

#### 3. UI Tests

```swift
import XCTest

final class VideoPlayerUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        app = XCUIApplication()
        app.launch()
    }

    func testFavoriteToggle() {
        let favoriteButton = app.buttons["Favorite"]
        favoriteButton.tap()

        // Verify heart icon changes
        XCTAssertTrue(app.images["heart.fill"].exists)
    }
}
```

#### 4. Preview Testing (Already Present)

```swift
#Preview {
    ContentView()
        .modelContainer(for: [VideoMetadata.self, Playlist.self])
}
```

**Previews are useful for:**
- Visual regression testing (manual)
- Quick UI iteration
- Component isolation

---

## Quick Reference

### File Path Reference

```
App Entry:     /home/user/SwiftUI_VideoPlayer_example/VideoPlayer/VideoPlayerApp.swift
Models:        /home/user/SwiftUI_VideoPlayer_example/VideoPlayer/Models.swift
Main Player:   /home/user/SwiftUI_VideoPlayer_example/VideoPlayer/ContentView.swift
History:       /home/user/SwiftUI_VideoPlayer_example/VideoPlayer/VideoHistoryView.swift
Playlists:     /home/user/SwiftUI_VideoPlayer_example/VideoPlayer/PlaylistManagementView.swift
Add to List:   /home/user/SwiftUI_VideoPlayer_example/VideoPlayer/AddToPlaylistView.swift
Transfer:      /home/user/SwiftUI_VideoPlayer_example/VideoPlayer/VideoTransferable.swift
Project:       /home/user/SwiftUI_VideoPlayer_example/VideoPlayer.xcodeproj/project.pbxproj
```

### Common Code Snippets

#### Access ModelContext
```swift
@Environment(\.modelContext) private var modelContext
```

#### Query All Videos
```swift
@Query private var videoMetadata: [VideoMetadata]
```

#### Save Changes
```swift
try? modelContext.save()
```

#### Delete Object
```swift
modelContext.delete(object)
try? modelContext.save()
```

#### Show Sheet
```swift
@State private var showingSheet = false

.sheet(isPresented: $showingSheet) {
    MyView()
}
```

#### Format Time
```swift
let minutes = Int(seconds) / 60
let secs = Int(seconds) % 60
String(format: "%d:%02d", minutes, secs)
```

---

## For AI Assistants: Best Practices

### When Working on This Codebase

1. ✅ **Always read CLAUDE.md first** before making changes
2. ✅ **Use TodoWrite** for multi-step tasks
3. ✅ **Reference files with line numbers** when discussing code (e.g., `ContentView.swift:123`)
4. ✅ **Check all affected files** when modifying models
5. ✅ **Preserve existing patterns** (don't introduce new architectural styles)
6. ✅ **Test with Xcode Previews** when possible
7. ✅ **Update CLAUDE.md** if you make architectural changes
8. ✅ **Follow naming conventions** strictly
9. ✅ **Use SwiftData patterns** consistently
10. ✅ **Handle errors properly** (don't use `try?` for new code)

### What to Ask the User

❓ When you're unsure:
- "Should I add error handling UI for this operation?"
- "Do you want this to sync with CloudKit?"
- "Should I create tests for this new feature?"
- "What should happen if the video file is missing?"
- "Should I implement loading indicators?"

❓ For design decisions:
- "Where should this new button appear?"
- "What should the default value be?"
- "Should this be optional or required?"

### What NOT to Do

❌ Don't:
- Push to main/master without permission
- Introduce external dependencies without asking
- Change architectural patterns (stay with MVVM + SwiftData)
- Use UIKit (this is pure SwiftUI)
- Remove existing features without asking
- Change iOS deployment target without asking
- Add localization files (not currently implemented)
- Create markdown files (except when updating CLAUDE.md)

---

## Changelog

### 2025-11-17 (Initial Creation)
- Created comprehensive CLAUDE.md
- Documented all 7 source files
- Analyzed architecture and patterns
- Mapped data flow and relationships
- Listed all features and constraints
- Provided common tasks and examples
- Added quick reference section

---

## Contributing to CLAUDE.md

When updating this file:

1. Keep the structure consistent
2. Update "Last Updated" date at the top
3. Add entry to Changelog section
4. Use concrete examples (file paths, line numbers, code snippets)
5. Test accuracy of code examples
6. Keep quick reference section up-to-date
7. Update file path references if files move
8. Commit with message: `docs: update CLAUDE.md - [what changed]`

---

**End of CLAUDE.md** • This document is maintained for AI assistants working on the SwiftUI VideoPlayer project.

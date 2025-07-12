import SwiftUI
import AVKit
import AppKit

struct ContentView: View {
    @StateObject private var fileProcessor = FileProcessor()
    @State private var selectedFile: FileInfo?
    
    var body: some View {
        NavigationView {
            // Sidebar with file list
            FileListView(fileProcessor: fileProcessor, selectedFile: $selectedFile)
                .frame(minWidth: 300, idealWidth: 350)
            
            // Detail view for selected file
            if let selectedFile = selectedFile {
                FileDetailView(file: selectedFile)
            } else {
                // Placeholder when no file is selected
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("Select a file to preview")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Choose a photo, video, or audio file from the list to view it here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .navigationTitle("Dedup")
        .navigationSubtitle("Media File Deduplication Tool")
        .alert("Error", isPresented: .constant(fileProcessor.errorMessage != nil)) {
            Button("OK") {
                fileProcessor.errorMessage = nil
            }
        } message: {
            if let errorMessage = fileProcessor.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

struct FileListView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedFile: FileInfo?
    @State private var selectedTab = 2 // Default to Settings tab
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Dedup")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityIdentifier("app-title")
                
                Text("Media File Deduplication Tool")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("app-subtitle")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            // Tab buttons
            HStack(spacing: 0) {
                tabButton(title: "Files to Move", index: 0, systemImage: "folder.badge.plus", identifier: "tabButton-filesToMove")
                tabButton(title: "Duplicates", index: 1, systemImage: "doc.on.doc", identifier: "tabButton-duplicates")
                tabButton(title: "Settings", index: 2, systemImage: "gear", identifier: "tabButton-settings")
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .background(Color(NSColor.windowBackgroundColor))
            
            // File list content
            Group {
                if selectedTab == 0 {
                    FilesToMoveListView(fileProcessor: fileProcessor, selectedFile: $selectedFile)
                } else if selectedTab == 1 {
                    DuplicatesListView(fileProcessor: fileProcessor, selectedFile: $selectedFile)
                } else {
                    SettingsView(fileProcessor: fileProcessor, selectedTab: $selectedTab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: fileProcessor.isProcessing) { oldValue, newValue in
            // Automatically switch to Files to Move tab when processing starts
            if newValue && selectedTab != 0 {
                selectedTab = 0
            }
        }
    }
    
    // Custom tab button styled as a segmented control
    @ViewBuilder
    private func tabButton(title: String, index: Int, systemImage: String, identifier: String) -> some View {
        Button(action: { 
            selectedTab = index
            selectedFile = nil // Clear selection when switching tabs
        }) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(selectedTab == index ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(selectedTab == index ? Color.accentColor : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selectedTab == index ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: selectedTab == index ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(identifier)
    }
}

struct FilesToMoveListView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedFile: FileInfo?
    @State private var selectedFiles: Set<FileInfo> = []
    @State private var selectAll = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Files to Move")
                    .font(.headline)
                Spacer()
                Button("Select All") {
                    if selectAll {
                        selectedFiles.removeAll()
                        selectAll = false
                    } else {
                        selectedFiles = Set(fileProcessor.filesToMove)
                        selectAll = true
                    }
                }
                .disabled(fileProcessor.filesToMove.isEmpty)
                .accessibilityIdentifier("button-selectAllFiles")
                Button("Move Selected") {
                    Task {
                        await fileProcessor.moveSelectedFiles(Array(selectedFiles))
                        selectedFiles.removeAll()
                        selectAll = false
                    }
                }
                .disabled(selectedFiles.isEmpty)
                .accessibilityIdentifier("button-moveSelectedFiles")
            }
            .padding(.horizontal)
            
            if fileProcessor.filesToMove.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No files to move")
                        .font(.headline)
                        .accessibilityIdentifier("label-noFilesToMove")
                    Text("Select source and target directories, then start processing to see files that can be moved.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(fileProcessor.filesToMove, id: \.id, selection: $selectedFile) { file in
                    HStack {
                        Button(action: {
                            if selectedFiles.contains(file) {
                                selectedFiles.remove(file)
                            } else {
                                selectedFiles.insert(file)
                            }
                        }) {
                            Image(systemName: selectedFiles.contains(file) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedFiles.contains(file) ? .accentColor : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("checkbox-file-\(file.id)")
                        
                        FileRowView(file: file)
                            .onTapGesture {
                                selectedFile = file
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct DuplicatesListView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedFile: FileInfo?
    @State private var selectedDuplicates: Set<FileInfo> = []
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Duplicate Groups")
                    .font(.headline)
                
                Spacer()
                
                Button("Delete Selected") {
                    Task {
                        await fileProcessor.deleteSelectedDuplicates(Array(selectedDuplicates))
                        selectedDuplicates.removeAll()
                    }
                }
                .disabled(selectedDuplicates.isEmpty)
                .accessibilityIdentifier("button-deleteSelected")
            }
            .padding(.horizontal)
            
            if fileProcessor.duplicateGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No duplicates found")
                        .font(.headline)
                        .accessibilityIdentifier("label-noDuplicates")
                    
                    Text("Select source and target directories, then start processing to see duplicate files.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(fileProcessor.duplicateGroups.enumerated()), id: \.offset) { index, group in
                        Section(header: Text("Group \(index + 1) (\(group.count) files)")) {
                            ForEach(group, id: \.id) { file in
                                DuplicateFileRowView(file: file, group: group)
                                    .onTapGesture {
                                        selectedFile = file
                                    }
                                    .background(selectedDuplicates.contains(file) ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .onTapGesture {
                                        if selectedDuplicates.contains(file) {
                                            selectedDuplicates.remove(file)
                                        } else {
                                            selectedDuplicates.insert(file)
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

struct FileDetailView: View {
    let file: FileInfo
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?
    @State private var videoError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // File information header
            VStack(alignment: .leading, spacing: 8) {
                Text(file.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                // Basic file info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Size: \(file.formattedSize)")
                        Text("Created: \(file.formattedCreationDate)")
                        Text("Type: \(file.mediaType.displayName)")
                    }
                    
                    Spacer()
                    
                    // Media-specific metadata
                    VStack(alignment: .trailing, spacing: 4) {
                        if file.width != nil && file.height != nil {
                            Text("Dimensions: \(file.formattedDimensions)")
                            Text("Aspect Ratio: \(file.formattedAspectRatio)")
                        }
                        
                        if file.duration != nil {
                            Text("Duration: \(file.formattedDuration)")
                        }
                        
                        if file.frameRate != nil {
                            Text("Frame Rate: \(file.formattedFrameRate)")
                        }
                        
                        if file.bitRate != nil {
                            Text("Bit Rate: \(file.formattedBitRate)")
                        }
                        
                        if let codec = file.codec {
                            Text("Codec: \(codec)")
                        }
                        
                        if let colorDepth = file.colorDepth {
                            Text("Color Depth: \(colorDepth) bit")
                        }
                        
                        if let colorSpace = file.colorSpace {
                            Text("Color Space: \(colorSpace)")
                        }
                        
                        if file.mediaType == .video || file.mediaType == .audio {
                            Text("Audio: \(file.formattedAudioInfo)")
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Show in Finder button
                Button(action: {
                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                }) {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Media content
            Group {
                if !file.isViewable {
                    UnsupportedFileView(file: file)
                        .id(file.id)
                        .onAppear {
                            print("DEBUG: File not viewable - \(file.displayName), mediaType: \(file.mediaType.rawValue), isViewable: \(file.isViewable)")
                        }
                } else {
                    switch file.mediaType {
                    case .photo:
                        if file.isRAWFile {
                            RAWImageView(file: file)
                                .id(file.id)
                        } else {
                            PhotoView(file: file)
                                .id(file.id)
                        }
                    case .video:
                        if file.fileExtension.lowercased() == "braw" {
                            BRAWVideoView(file: file, player: $player, isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, timer: $timer)
                                .id(file.id)
                        } else {
                            VideoView(file: file, player: $player, isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, timer: $timer)
                                .id(file.id)
                        }
                    case .audio:
                        AudioView(file: file, player: $player, isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, timer: $timer)
                            .id(file.id)
                    case .unsupported:
                        UnsupportedFileView(file: file)
                            .id(file.id)
                            .onAppear {
                                print("DEBUG: Unsupported media type - \(file.displayName), mediaType: \(file.mediaType.rawValue)")
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.green.opacity(0.1)) // Debug media content area restored
            .onAppear {
                print("DEBUG: Media content area appeared for: \(file.displayName)")
                print("DEBUG: Media content area green background visible - \(file.displayName)")
            }
        }
        .onAppear {
            print("DEBUG: FileDetailView appeared for file: \(file.displayName)")
        }
        .onDisappear {
            print("DEBUG: FileDetailView disappeared for file: \(file.displayName)")
            cleanupPlayer()
        }
    }
    
    private var iconName: String {
        switch file.mediaType {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        case .unsupported:
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        case .unsupported:
            return .orange
        }
    }
    
    private func cleanupPlayer() {
        timer?.invalidate()
        timer = nil
        player?.pause()
        
        // Remove notification observers
        if let playerItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        }
        
        // Don't set player to nil - this causes the controls to disappear
        // The player will be replaced in setupPlayer for the next file
    }
}

struct PhotoView: View {
    let file: FileInfo
    @State private var image: NSImage?
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 16) {
            if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Error loading image")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                    }) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            } else if let image = image {
                GeometryReader { geometry in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geometry.size.width > 0 && image.size.height > 0 ? min(geometry.size.width, geometry.size.height * image.size.width / image.size.height) : 100,
                            height: geometry.size.height > 0 && image.size.width > 0 ? min(geometry.size.height, geometry.size.width * image.size.height / image.size.width) : 100
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // No image loaded
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Loading image...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.all, 10) // Reduced padding for more content space
        .onAppear {
            print("DEBUG: PhotoView appeared for file: \(file.displayName)")
            loadImage()
        }
        .onDisappear {
            print("DEBUG: PhotoView disappeared for file: \(file.displayName)")
        }
    }
    
    private func loadImage() {
        print("DEBUG: PhotoView - Starting to load image for: \(file.displayName)")
        guard let image = NSImage(contentsOf: file.url) else {
            print("DEBUG: PhotoView - Failed to load image from URL: \(file.url)")
            error = "Could not load image"
            return
        }
        print("DEBUG: PhotoView - Image loaded successfully: \(file.displayName), size: \(image.size)")
        self.image = image
    }
}

struct VideoView: View {
    let file: FileInfo
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var timer: Timer?
    @State private var videoError: String?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Video player
            if let player = player, player.currentItem != nil, player.currentItem?.status != .failed {
                GeometryReader { geometry in
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.red.opacity(0.3)) // Debug background restored
                        .onAppear {
                            print("DEBUG: VideoPlayer frame - available: \(geometry.size.width) x \(geometry.size.height)")
                            print("DEBUG: VideoPlayer appeared for: \(file.displayName)")
                        }
                        .onDisappear {
                            print("DEBUG: VideoPlayer disappeared for: \(file.displayName)")
                        }
                }
            } else if let videoError = videoError {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                Text("Video Error")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(videoError)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                }
                .onAppear {
                    print("DEBUG: VideoView showing error - \(file.displayName), error: \(videoError)")
                }
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView("Loading video...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onAppear {
                    print("DEBUG: VideoView showing loading - \(file.displayName)")
                }
            } else {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "video")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("Video not available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                }
                .onAppear {
                    print("DEBUG: VideoView showing 'not available' - \(file.displayName)")
                    print("DEBUG: VideoView state - player: \(player != nil), isLoading: \(isLoading), videoError: \(videoError ?? "none")")
                }
            }
        }
        .padding(.all, 10) // Reduced padding for more video space
        .background(Color.blue.opacity(0.1)) // Debug container background restored
        .onAppear {
            print("DEBUG: VideoView appeared for file: \(file.displayName)")
            resetState()
            setupPlayer()
        }
        .onDisappear {
            print("DEBUG: VideoView disappeared for file: \(file.displayName)")
            cleanupPlayer()
        }
    }
    
    private func resetState() {
        print("DEBUG: VideoView - Resetting state for: \(file.displayName)")
        isLoading = true
        videoError = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        // Don't reset the player here - let setupPlayer handle it
    }
    
    private func setupPlayer() {
        print("DEBUG: VideoView - Setting up player for: \(file.displayName)")
        isLoading = true
        
        // Clean up timer only, don't reset player yet
        timer?.invalidate()
        timer = nil
        
        // Add safety check for URL
        guard file.url.isFileURL else {
            print("DEBUG: VideoView - Invalid file URL: \(file.url)")
            videoError = "Invalid file URL"
            isLoading = false
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: file.url.path) else {
            print("DEBUG: VideoView - File does not exist: \(file.url.path)")
            videoError = "File does not exist"
            isLoading = false
            return
        }
        
        // Try to create AVPlayer for video with error handling
        // Create the player on the main queue to avoid threading issues
        DispatchQueue.main.async {
            // Create AVPlayer with error handling
            let playerItem = AVPlayerItem(url: file.url)
            self.player = AVPlayer(playerItem: playerItem)
            print("DEBUG: VideoView - Player created for: \(file.displayName), player: \(self.player != nil)")
            
            // Verify player was created successfully
            guard self.player != nil else {
                print("DEBUG: VideoView - Failed to create player")
                self.videoError = "Failed to create video player"
                self.isLoading = false
                return
            }
            
            // Add observer for player item status
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                print("DEBUG: VideoView - Player item failed to play")
                self.videoError = "Video failed to play"
                self.isLoading = false
            }
            
            // Get duration and set loading to false
            let asset = AVURLAsset(url: file.url)
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    await MainActor.run {
                        self.duration = CMTimeGetSeconds(duration)
                        self.isLoading = false
                        print("DEBUG: VideoView - Video loaded successfully: \(file.displayName), duration: \(self.duration), player: \(self.player != nil)")
                    }
                } catch {
                    await MainActor.run {
                        self.videoError = "Could not load video duration: \(error.localizedDescription)"
                        self.isLoading = false
                        print("DEBUG: VideoView - Error loading video: \(error.localizedDescription)")
                    }
                }
            }
            
            // Set loading to false after a short delay to ensure player is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.player != nil && self.player?.currentItem != nil {
                    self.isLoading = false
                    print("DEBUG: VideoView - Player ready, setting loading to false")
                } else {
                    print("DEBUG: VideoView - Player not ready, showing error")
                    self.videoError = "Failed to initialize video player"
                    self.isLoading = false
                }
            }
            
            // Setup timer for progress updates
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let player = self.player {
                    self.currentTime = CMTimeGetSeconds(player.currentTime())
                }
            }
        }
    }
    
    private func cleanupPlayer() {
        timer?.invalidate()
        timer = nil
        player?.pause()
        
        // Remove notification observers
        if let playerItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        }
        
        // Don't set player to nil - this causes the controls to disappear
        // The player will be replaced in setupPlayer for the next file
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct AudioView: View {
    let file: FileInfo
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var timer: Timer?
    @State private var isLoading = true
    @State private var audioError: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Audio visualizer placeholder
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "music.note")
                        .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.15))
                        .foregroundColor(.green)
                    
                    Text(file.displayName)
                        .font(.title2)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    Text(file.mediaType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                    }) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // Audio controls - show if player exists and is not loading
            if player != nil && !isLoading {
                VStack(spacing: 12) {
                    // Progress slider
                    Slider(value: Binding(
                        get: { currentTime },
                        set: { newValue in
                            if let player = player {
                                let time = CMTime(seconds: newValue, preferredTimescale: 1)
                                player.seek(to: time)
                                currentTime = newValue
                            }
                        }
                    ), in: 0...max(duration, 1))
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            if isPlaying {
                                player?.pause()
                            } else {
                                player?.play()
                            }
                            isPlaying.toggle()
                        }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.bordered)
                        
                        Spacer()
                        
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor))
                .cornerRadius(8)
            } else if isLoading {
                VStack(spacing: 12) {
                    ProgressView("Loading audio...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .padding(.all, 10) // Reduced padding for more content space
        .background(Color.green.opacity(0.1)) // Debug background
        .onAppear {
            print("DEBUG: AudioView appeared for file: \(file.displayName)")
            resetState()
            setupPlayer()
        }
        .onDisappear {
            print("DEBUG: AudioView disappeared for file: \(file.displayName)")
            cleanupPlayer()
        }
    }
    
    private func resetState() {
        print("DEBUG: AudioView - Resetting state for: \(file.displayName)")
        isLoading = true
        audioError = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        // Don't reset the player here - let setupPlayer handle it
    }
    
    private func setupPlayer() {
        print("DEBUG: AudioView - Setting up player for: \(file.displayName)")
        isLoading = true
        
        // Clean up timer only, don't reset player yet
        timer?.invalidate()
        timer = nil
        
        // Add safety check for URL
        guard file.url.isFileURL else {
            print("DEBUG: AudioView - Invalid file URL: \(file.url)")
            audioError = "Invalid file URL"
            isLoading = false
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: file.url.path) else {
            print("DEBUG: AudioView - File does not exist: \(file.url.path)")
            audioError = "File does not exist"
            isLoading = false
            return
        }
        
        // Create AVPlayer with error handling
        DispatchQueue.main.async {
            self.player = AVPlayer(url: file.url)
            print("DEBUG: AudioView - Player created for: \(file.displayName), player: \(self.player != nil)")
            
            // Verify player was created successfully
            guard self.player != nil else {
                print("DEBUG: AudioView - Failed to create player")
                self.audioError = "Failed to create audio player"
                self.isLoading = false
                return
            }
            
            // Get duration
            let asset = AVURLAsset(url: file.url)
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    await MainActor.run {
                        self.duration = CMTimeGetSeconds(duration)
                        self.isLoading = false
                        print("DEBUG: AudioView - Audio loaded successfully: \(file.displayName), duration: \(self.duration), player: \(self.player != nil)")
                    }
                } catch {
                    await MainActor.run {
                        self.audioError = "Could not load audio duration: \(error.localizedDescription)"
                        self.isLoading = false
                        print("DEBUG: AudioView - Error loading audio: \(error.localizedDescription)")
                    }
                }
            }
            
            // Set loading to false after a short delay to ensure player is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.player != nil {
                    self.isLoading = false
                    print("DEBUG: AudioView - Player ready, setting loading to false")
                } else {
                    print("DEBUG: AudioView - Player not ready, showing error")
                    self.audioError = "Failed to initialize audio player"
                    self.isLoading = false
                }
            }
            
            // Setup timer for progress updates
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let player = self.player {
                    self.currentTime = CMTimeGetSeconds(player.currentTime())
                }
            }
        }
    }
    
    private func cleanupPlayer() {
        timer?.invalidate()
        timer = nil
        player?.pause()
        
        // Remove notification observers
        if let playerItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        }
        
        // Don't set player to nil - this causes the controls to disappear
        // The player will be replaced in setupPlayer for the next file
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct UnsupportedFileView: View {
    let file: FileInfo
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                Spacer()
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.15))
                    .foregroundColor(.orange)
                
                Text("Unable to View")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("This file type (\(file.fileExtension.uppercased())) is not supported for preview.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                }) {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.all, 10) // Reduced padding for more content space
        .onAppear {
            print("DEBUG: UnsupportedFileView appeared for file: \(file.displayName)")
        }
        .onDisappear {
            print("DEBUG: UnsupportedFileView disappeared for file: \(file.displayName)")
        }
    }
}

struct FileRowView: View {
    let file: FileInfo
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(file.url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    Text(file.mediaType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(mediaTypeColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(file.formattedCreationDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Show in Finder button
            Button(action: {
                NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
            }) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch file.mediaType {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        case .unsupported:
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        case .unsupported:
            return .orange
        }
    }
    
    private var mediaTypeColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        case .unsupported:
            return .orange
        }
    }
}

struct DuplicateFileRowView: View {
    let file: FileInfo
    let group: [FileInfo]
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(file.url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    Text(file.mediaType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(mediaTypeColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(file.formattedCreationDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show duplicate count and locations
                if group.count > 1 {
                    Text("Duplicate of \(group.count - 1) other file(s)")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    
                    // Show list of duplicate paths
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(group.filter { $0.id != file.id }, id: \.id) { duplicateFile in
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                Text(duplicateFile.url.path)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.leading, 8)
                }
            }
            
            Spacer()
            
            // Show in Finder button
            Button(action: {
                NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
            }) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch file.mediaType {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        case .unsupported:
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        case .unsupported:
            return .orange
        }
    }
    
    private var mediaTypeColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        case .unsupported:
            return .orange
        }
    }
}

struct SettingsView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedTab: Int
    
    enum ProcessingState {
        case initial, ready, processing, done
    }
    @State private var state: ProcessingState = .initial
    @State private var lastSourceURL: URL?
    @State private var lastTargetURL: URL?
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Directory Selection")
                    .font(.headline)
                    .accessibilityIdentifier("label-directorySelection")
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source Directory")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(fileProcessor.sourceURL != nil ? "\(fileProcessor.sourceFiles.count) files found" : "Not selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("label-sourceDirectoryStatus")
                    }
                    Spacer()
                    Button("Select Source") {
                        Task {
                            await fileProcessor.selectSourceDirectory()
                        }
                    }
                    .accessibilityIdentifier("button-selectSource")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Directory")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(fileProcessor.targetURL != nil ? "\(fileProcessor.targetFiles.count) files found" : "Not selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("label-targetDirectoryStatus")
                    }
                    Spacer()
                    Button("Select Target") {
                        Task {
                            await fileProcessor.selectTargetDirectory()
                        }
                    }
                    .accessibilityIdentifier("button-selectTarget")
                }
            }
            Divider()
            // Always show status and button
            VStack(alignment: .leading, spacing: 12) {
                Text(statusText)
                    .font(.headline)
                    .accessibilityIdentifier(statusIdentifier)
                Button(buttonLabel) {
                    state = .processing
                    Task {
                        await fileProcessor.startProcessing()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!buttonEnabled)
                .accessibilityIdentifier(buttonIdentifier)
            }
            if state == .processing {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Processing files...")
                        .font(.subheadline)
                        .accessibilityIdentifier("label-processingStatus")
                    ProgressView(value: fileProcessor.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text(fileProcessor.currentOperation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("label-processingOperation")
                }
            }
            Spacer()
        }
        .padding()
        .onAppear {
            updateState()
        }
        .onChange(of: fileProcessor.isProcessing) { oldValue, newValue in
            if newValue {
                state = .processing
            } else if oldValue && !newValue {
                state = .done
            }
        }
        .onChange(of: fileProcessor.sourceURL) { oldValue, newValue in
            if oldValue != newValue {
                lastSourceURL = newValue
                updateState()
            }
        }
        .onChange(of: fileProcessor.targetURL) { oldValue, newValue in
            if oldValue != newValue {
                lastTargetURL = newValue
                updateState()
            }
        }
    }
    
    private func updateState() {
        if fileProcessor.sourceURL == nil || fileProcessor.targetURL == nil {
            state = .initial
        } else if state == .done {
            // If either folder changed after done, go back to ready
            if lastSourceURL != fileProcessor.sourceURL || lastTargetURL != fileProcessor.targetURL {
                state = .ready
            }
        } else {
            state = .ready
        }
    }
    
    private var statusText: String {
        switch state {
        case .initial: return "Select Folders"
        case .ready: return "Ready to Process"
        case .processing: return "Processing"
        case .done: return "Done Processing"
        }
    }
    private var statusIdentifier: String {
        switch state {
        case .initial: return "label-selectFolders"
        case .ready: return "label-readyToProcess"
        case .processing: return "label-processing"
        case .done: return "label-doneProcessing"
        }
    }
    private var buttonLabel: String {
        switch state {
        case .processing, .done: return "Processing..."
        default: return "Start Processing"
        }
    }
    private var buttonIdentifier: String {
        switch state {
        case .processing, .done: return "button-processing"
        default: return "button-startProcessing"
        }
    }
    private var buttonEnabled: Bool {
        state == .ready
    }
}

struct RAWImageView: View {
    let file: FileInfo
    @State private var image: NSImage?
    @State private var error: String?
    @State private var isLoading = true
    @State private var rawMetadata: RAWMetadata?
    @State private var showExternalViewerOption = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Image viewer or preview
            if let image = image {
                GeometryReader { geometry in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geometry.size.width > 0 && image.size.height > 0 ? min(geometry.size.width, geometry.size.height * image.size.width / image.size.height) : 100,
                            height: geometry.size.height > 0 && image.size.width > 0 ? min(geometry.size.height, geometry.size.width * image.size.height / image.size.width) : 100
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.blue.opacity(0.1))
                }
            } else if let error = error {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                Text("RAW Image Error")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                if showExternalViewerOption {
                                    Button("Open with External Viewer") {
                                        openWithExternalViewer()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                }
                .onAppear {
                    print("DEBUG: RAWImageView showing error - \(file.displayName), error: \(error)")
                }
            } else if isLoading {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                ProgressView("Loading RAW image...")
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("RAW files may take longer to load")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let metadata = rawMetadata {
                                    VStack(spacing: 4) {
                                        Text("Resolution: \(metadata.resolution)")
                                            .font(.caption)
                                        Text("Color Depth: \(metadata.colorDepth)")
                                            .font(.caption)
                                        Text("Format: \(metadata.format)")
                                            .font(.caption)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        )
                        .cornerRadius(8)
                }
                .onAppear {
                    print("DEBUG: RAWImageView showing loading - \(file.displayName)")
                }
            } else {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("RAW Image Preview")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                if let metadata = rawMetadata {
                                    VStack(spacing: 4) {
                                        Text("Resolution: \(metadata.resolution)")
                                            .font(.caption)
                                        Text("Color Depth: \(metadata.colorDepth)")
                                            .font(.caption)
                                        Text("Format: \(metadata.format)")
                                            .font(.caption)
                                    }
                                    .padding(.vertical, 8)
                                }
                                
                                Button("Open with External Viewer") {
                                    openWithExternalViewer()
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                }
                .onAppear {
                    print("DEBUG: RAWImageView showing preview - \(file.displayName)")
                }
            }
        }
        .padding(.all, 10)
        .background(Color.blue.opacity(0.1))
        .onAppear {
            print("DEBUG: RAWImageView appeared for file: \(file.displayName)")
            resetState()
            setupRAWImage()
        }
        .onDisappear {
            print("DEBUG: RAWImageView disappeared for file: \(file.displayName)")
        }
    }
    
    private func resetState() {
        print("DEBUG: RAWImageView - Resetting state for: \(file.displayName)")
        isLoading = true
        error = nil
        image = nil
        rawMetadata = nil
        showExternalViewerOption = false
    }
    
    private func setupRAWImage() {
        print("DEBUG: RAWImageView - Setting up RAW image for: \(file.displayName)")
        isLoading = true
        
        // Validate file
        guard file.url.isFileURL else {
            print("DEBUG: RAWImageView - Invalid file URL: \(file.url)")
            error = "Invalid file URL"
            isLoading = false
            return
        }
        
        guard FileManager.default.fileExists(atPath: file.url.path) else {
            print("DEBUG: RAWImageView - File does not exist: \(file.url.path)")
            error = "File does not exist"
            isLoading = false
            return
        }
        
        // Extract RAW metadata first
        Task {
            await extractRAWMetadata()
            
            // Try multiple approaches for RAW image viewing
            await MainActor.run {
                setupRAWImageLoading()
            }
        }
    }
    
    private func extractRAWMetadata() async {
        print("DEBUG: RAWImageView - Extracting RAW metadata for: \(file.displayName)")
        
        // Use RAWSupport utility
        if let metadata = await RAWSupport.shared.extractRAWMetadata(from: file.url) {
            await MainActor.run {
                self.rawMetadata = metadata
            }
        }
    }
    
    private func setupRAWImageLoading() {
        print("DEBUG: RAWImageView - Setting up RAW image loading for: \(file.displayName)")
        
        // Try multiple approaches for RAW image viewing
        
        // Approach 1: Try with NSImage (might work with some RAW files)
        DispatchQueue.main.async {
            if let loadedImage = NSImage(contentsOf: file.url) {
                print("DEBUG: RAWImageView - NSImage loaded successfully: \(file.displayName)")
                self.image = loadedImage
                self.isLoading = false
                return
            }
            
            // Approach 2: Try FFmpeg conversion
            if RAWSupport.shared.hasFFmpeg {
                Task {
                    await tryFFmpegConversion()
                }
                return
            }
            
            // Approach 3: Check for available RAW viewers
            if RAWSupport.shared.hasRAWViewingSupport {
                self.showExternalViewerOption = true
                self.isLoading = false
                self.error = "RAW files require specialized software for viewing. Use the 'Open with External Viewer' button."
                return
            }
            
            // Final fallback
            self.showExternalViewerOption = true
            self.isLoading = false
            self.error = "RAW files require specialized software. Install Capture One, Lightroom, or use Preview.app for viewing."
        }
    }
    
    private func tryFFmpegConversion() async {
        print("DEBUG: RAWImageView - Attempting FFmpeg conversion")
        
        if let convertedURL = await RAWSupport.shared.convertRAWToJPEG(file.url) {
            await MainActor.run {
                if let convertedImage = NSImage(contentsOf: convertedURL) {
                    self.image = convertedImage
                    self.isLoading = false
                    print("DEBUG: RAWImageView - FFmpeg conversion successful")
                } else {
                    self.error = "FFmpeg conversion failed to create viewable image"
                    self.isLoading = false
                }
            }
        } else {
            await MainActor.run {
                self.error = "FFmpeg conversion failed"
                self.isLoading = false
            }
        }
    }
    
    private func openWithExternalViewer() {
        RAWSupport.shared.openRAWFile(file.url)
    }
}

struct BRAWVideoView: View {
    let file: FileInfo
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var timer: Timer?
    @State private var videoError: String?
    @State private var isLoading = true
    @State private var brawMetadata: BRAWMetadata?
    @State private var showExternalPlayerOption = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Video player or preview
            if let player = player, player.currentItem != nil, player.currentItem?.status != .failed {
                GeometryReader { geometry in
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.red.opacity(0.3))
                        .onAppear {
                            print("DEBUG: BRAW VideoPlayer frame - available: \(geometry.size.width) x \(geometry.size.height)")
                            print("DEBUG: BRAW VideoPlayer appeared for: \(file.displayName)")
                        }
                        .onDisappear {
                            print("DEBUG: BRAW VideoPlayer disappeared for: \(file.displayName)")
                        }
                }
            } else if let videoError = videoError {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                Text("BRAW Video Error")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text(videoError)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                if showExternalPlayerOption {
                                    Button("Open with External Player") {
                                        openWithExternalPlayer()
                                    }
                                    .buttonStyle(.bordered)
                                }
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                }
                .onAppear {
                    print("DEBUG: BRAWVideoView showing error - \(file.displayName), error: \(videoError)")
                }
            } else if isLoading {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                ProgressView("Loading BRAW video...")
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("BRAW files may take longer to load")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                if let metadata = brawMetadata {
                                    VStack(spacing: 4) {
                                        Text("Resolution: \(metadata.resolution)")
                                            .font(.caption)
                                        Text("Frame Rate: \(metadata.frameRate)")
                                            .font(.caption)
                                        Text("Codec: \(metadata.codec)")
                                            .font(.caption)
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        )
                        .cornerRadius(8)
                }
                .onAppear {
                    print("DEBUG: BRAWVideoView showing loading - \(file.displayName)")
                }
            } else {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color(.controlBackgroundColor))
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "video")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("BRAW Video Preview")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                if let metadata = brawMetadata {
                                    VStack(spacing: 4) {
                                        Text("Resolution: \(metadata.resolution)")
                                            .font(.caption)
                                        Text("Frame Rate: \(metadata.frameRate)")
                                            .font(.caption)
                                        Text("Codec: \(metadata.codec)")
                                            .font(.caption)
                                    }
                                    .padding(.vertical, 8)
                                }
                                
                                Button("Open with External Player") {
                                    openWithExternalPlayer()
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: {
                                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                                }) {
                                    Label("Show in Finder", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        )
                }
                .onAppear {
                    print("DEBUG: BRAWVideoView showing preview - \(file.displayName)")
                }
            }
        }
        .padding(.all, 10)
        .background(Color.blue.opacity(0.1))
        .onAppear {
            print("DEBUG: BRAWVideoView appeared for file: \(file.displayName)")
            resetState()
            setupBRAWPlayer()
        }
        .onDisappear {
            print("DEBUG: BRAWVideoView disappeared for file: \(file.displayName)")
            cleanupPlayer()
        }
    }
    
    private func resetState() {
        print("DEBUG: BRAWVideoView - Resetting state for: \(file.displayName)")
        isLoading = true
        videoError = nil
        currentTime = 0
        duration = 0
        isPlaying = false
        brawMetadata = nil
        showExternalPlayerOption = false
    }
    
    private func setupBRAWPlayer() {
        print("DEBUG: BRAWVideoView - Setting up BRAW player for: \(file.displayName)")
        isLoading = true
        
        // Clean up timer only
        timer?.invalidate()
        timer = nil
        
        // Validate file
        guard file.url.isFileURL else {
            print("DEBUG: BRAWVideoView - Invalid file URL: \(file.url)")
            videoError = "Invalid file URL"
            isLoading = false
            return
        }
        
        guard FileManager.default.fileExists(atPath: file.url.path) else {
            print("DEBUG: BRAWVideoView - File does not exist: \(file.url.path)")
            videoError = "File does not exist"
            isLoading = false
            return
        }
        
        // Extract BRAW metadata first
        Task {
            await extractBRAWMetadata()
            
            // Try multiple approaches for BRAW playback
            await MainActor.run {
                setupBRAWPlayback()
            }
        }
    }
    
    private func extractBRAWMetadata() async {
        print("DEBUG: BRAWVideoView - Extracting BRAW metadata for: \(file.displayName)")
        
        // Use BRAWSupport utility
        if let metadata = await BRAWSupport.shared.extractBRAWMetadata(from: file.url) {
            await MainActor.run {
                self.brawMetadata = metadata
            }
        }
    }
    

    
    private func setupBRAWPlayback() {
        print("DEBUG: BRAWVideoView - Setting up BRAW playback for: \(file.displayName)")
        
        // Try multiple approaches for BRAW playback
        
        // Approach 1: Try with AVPlayer (might work with some BRAW files)
        DispatchQueue.main.async {
            let playerItem = AVPlayerItem(url: file.url)
            self.player = AVPlayer(playerItem: playerItem)
            
            // Add observer for player item status
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemFailedToPlayToEndTime,
                object: playerItem,
                queue: .main
            ) { _ in
                print("DEBUG: BRAWVideoView - AVPlayer failed, trying alternative methods")
                self.tryAlternativeBRAWPlayback()
            }
            
            // Check if player is working
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.player?.currentItem?.status == .failed {
                    print("DEBUG: BRAWVideoView - AVPlayer failed, trying alternative methods")
                    self.tryAlternativeBRAWPlayback()
                } else {
                    self.isLoading = false
                    print("DEBUG: BRAWVideoView - AVPlayer working for BRAW file")
                }
            }
        }
    }
    
    private func tryAlternativeBRAWPlayback() {
        print("DEBUG: BRAWVideoView - Trying alternative BRAW playback methods")
        
        // Check for available BRAW players
        if BRAWSupport.shared.hasBlackmagicRAWPlayer {
            showExternalPlayerOption = true
            isLoading = false
            videoError = "BRAW files require Blackmagic RAW Player or DaVinci Resolve for playback. Use the 'Open with External Player' button."
            return
        }
        
        if BRAWSupport.shared.hasDaVinciResolve {
            showExternalPlayerOption = true
            isLoading = false
            videoError = "BRAW files require DaVinci Resolve for playback. Use the 'Open with External Player' button."
            return
        }
        
        // Try FFmpeg conversion (if available)
        if BRAWSupport.shared.hasFFmpeg {
            Task {
                await tryFFmpegConversion()
            }
            return
        }
        
        // Final fallback
        showExternalPlayerOption = true
        isLoading = false
        videoError = "BRAW files require specialized software. Install Blackmagic RAW Player, DaVinci Resolve, or FFmpeg for playback."
    }
    
    private func tryFFmpegConversion() async {
        print("DEBUG: BRAWVideoView - Attempting FFmpeg conversion")
        
        if let convertedURL = await BRAWSupport.shared.convertBRAWToMP4(file.url) {
            await MainActor.run {
                // Create player with converted file
                let playerItem = AVPlayerItem(url: convertedURL)
                self.player = AVPlayer(playerItem: playerItem)
                self.isLoading = false
                print("DEBUG: BRAWVideoView - FFmpeg conversion successful")
            }
        } else {
            await MainActor.run {
                self.videoError = "FFmpeg conversion failed"
                self.isLoading = false
            }
        }
    }
    
    private func openWithExternalPlayer() {
        BRAWSupport.shared.openBRAWFile(file.url)
    }
    
    private func cleanupPlayer() {
        timer?.invalidate()
        timer = nil
        player?.pause()
        
        // Remove notification observers
        if let playerItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
        }
        
        // Don't set player to nil - this causes the controls to disappear
        // The player will be replaced in setupPlayer for the next file
    }
}

// MARK: - BRAW Metadata Structure

struct BRAWMetadata {
    let resolution: String
    let frameRate: String
    let codec: String
    let duration: String
}

#Preview {
    ContentView()
}

// MARK: - BRAW Support Utilities

class BRAWSupport {
    static let shared = BRAWSupport()
    
    private init() {}
    
    /// Check if the system has BRAW playback capabilities
    var hasBRAWPlaybackSupport: Bool {
        return hasBlackmagicRAWPlayer || hasDaVinciResolve || hasFFmpeg
    }
    
    /// Check if Blackmagic RAW Player is installed
    var hasBlackmagicRAWPlayer: Bool {
        let possiblePaths = [
            "/Applications/Blackmagic RAW Player.app",
            "/Applications/Blackmagic RAW Player/Blackmagic RAW Player.app"
        ]
        
        return possiblePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// Check if DaVinci Resolve is installed
    var hasDaVinciResolve: Bool {
        let possiblePaths = [
            "/Applications/DaVinci Resolve/DaVinci Resolve.app",
            "/Applications/DaVinci Resolve.app"
        ]
        
        return possiblePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// Check if FFmpeg is available
    var hasFFmpeg: Bool {
        let ffmpegPaths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg"
        ]
        
        return ffmpegPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// Get the best available BRAW player
    var bestBRAWPlayer: String? {
        if hasBlackmagicRAWPlayer {
            return "Blackmagic RAW Player"
        } else if hasDaVinciResolve {
            return "DaVinci Resolve"
        } else if hasFFmpeg {
            return "FFmpeg"
        }
        return nil
    }
    
    /// Extract BRAW metadata using available tools
    func extractBRAWMetadata(from url: URL) async -> BRAWMetadata? {
        // Try FFmpeg first
        if hasFFmpeg {
            return await extractMetadataWithFFmpeg(url)
        }
        
        // Fallback to basic file info
        return BRAWMetadata(
            resolution: "Unknown",
            frameRate: "Unknown",
            codec: "BRAW",
            duration: "Unknown"
        )
    }
    
    private func extractMetadataWithFFmpeg(_ url: URL) async -> BRAWMetadata? {
        let ffmpegPath = "/usr/local/bin/ffmpeg"
        let systemFFmpegPath = "/opt/homebrew/bin/ffmpeg"
        
        let ffmpeg = FileManager.default.fileExists(atPath: ffmpegPath) ? ffmpegPath :
                     FileManager.default.fileExists(atPath: systemFFmpegPath) ? systemFFmpegPath : nil
        
        guard let ffmpegExecutable = ffmpeg else {
            return nil
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegExecutable)
        process.arguments = [
            "-i", url.path,
            "-f", "null",
            "-"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return parseBRAWMetadataFromFFmpeg(output)
        } catch {
            print("DEBUG: BRAWSupport - FFmpeg error: \(error)")
            return nil
        }
    }
    
    private func parseBRAWMetadataFromFFmpeg(_ output: String) -> BRAWMetadata? {
        let lines = output.components(separatedBy: .newlines)
        
        var resolution = "Unknown"
        var frameRate = "Unknown"
        var codec = "BRAW"
        var duration = "Unknown"
        
        for line in lines {
            if line.contains("Video:") {
                // Extract resolution
                if let resolutionMatch = line.range(of: #"(\d{2,4}x\d{2,4})"#, options: .regularExpression) {
                    resolution = String(line[resolutionMatch])
                }
                
                // Extract frame rate
                if let frameRateMatch = line.range(of: #"(\d+(?:\.\d+)?)\s*fps"#, options: .regularExpression) {
                    let frameRateString = String(line[frameRateMatch])
                    if let fps = frameRateString.components(separatedBy: " ").first {
                        frameRate = "\(fps) fps"
                    }
                }
                
                // Extract codec
                if let codecMatch = line.range(of: #"Video:\s+([^,\s]+)"#, options: .regularExpression) {
                    let codecString = String(line[codecMatch])
                    if let codecName = codecString.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) {
                        codec = codecName
                    }
                }
            }
            
            // Extract duration
            if line.contains("Duration:") {
                if let durationMatch = line.range(of: #"Duration:\s+(\d{2}:\d{2}:\d{2}\.\d{2})"#, options: .regularExpression) {
                    let durationString = String(line[durationMatch])
                    if let time = durationString.components(separatedBy: ":").last {
                        duration = time
                    }
                }
            }
        }
        
        return BRAWMetadata(
            resolution: resolution,
            frameRate: frameRate,
            codec: codec,
            duration: duration
        )
    }
    
    /// Convert BRAW file to MP4 using FFmpeg
    func convertBRAWToMP4(_ inputURL: URL) async -> URL? {
        guard hasFFmpeg else { return nil }
        
        let ffmpegPath = "/usr/local/bin/ffmpeg"
        let systemFFmpegPath = "/opt/homebrew/bin/ffmpeg"
        
        let ffmpeg = FileManager.default.fileExists(atPath: ffmpegPath) ? ffmpegPath :
                     FileManager.default.fileExists(atPath: systemFFmpegPath) ? systemFFmpegPath : nil
        
        guard let ffmpegExecutable = ffmpeg else {
            return nil
        }
        
        // Create temporary output file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString).mp4")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegExecutable)
        process.arguments = [
            "-i", inputURL.path,
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "23",
            "-c:a", "aac",
            "-b:a", "128k",
            "-y", // Overwrite output file
            outputURL.path
        ]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputURL.path) {
                return outputURL
            }
        } catch {
            print("DEBUG: BRAWSupport - FFmpeg conversion error: \(error)")
        }
        
        return nil
    }
    
    /// Open BRAW file with the best available player
    func openBRAWFile(_ url: URL) {
        // Try Blackmagic RAW Player first
        if hasBlackmagicRAWPlayer {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [
                "-a", "Blackmagic RAW Player",
                url.path
            ]
            
            do {
                try process.run()
                return
            } catch {
                print("DEBUG: BRAWSupport - Failed to open with Blackmagic RAW Player: \(error)")
            }
        }
        
        // Try DaVinci Resolve
        if hasDaVinciResolve {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [
                "-a", "DaVinci Resolve",
                url.path
            ]
            
            do {
                try process.run()
                return
            } catch {
                print("DEBUG: BRAWSupport - Failed to open with DaVinci Resolve: \(error)")
            }
        }
        
        // Fallback to default application
        NSWorkspace.shared.open(url)
    }
}

// MARK: - RAW Image Support Utilities

class RAWSupport {
    static let shared = RAWSupport()
    
    private init() {}
    
    /// Check if the system has RAW image viewing capabilities
    var hasRAWViewingSupport: Bool {
        return hasPreview || hasPhotos || hasLightroom || hasCaptureOne || hasFFmpeg
    }
    
    /// Check if Preview.app can handle RAW files
    var hasPreview: Bool {
        return true // Preview.app is always available on macOS
    }
    
    /// Check if Photos.app is installed
    var hasPhotos: Bool {
        return FileManager.default.fileExists(atPath: "/Applications/Photos.app")
    }
    
    /// Check if Adobe Lightroom is installed
    var hasLightroom: Bool {
        let possiblePaths = [
            "/Applications/Adobe Lightroom/Adobe Lightroom.app",
            "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app"
        ]
        
        return possiblePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// Check if Capture One is installed
    var hasCaptureOne: Bool {
        let possiblePaths = [
            "/Applications/Capture One/Capture One.app",
            "/Applications/Capture One 23/Capture One 23.app",
            "/Applications/Capture One 24/Capture One 24.app"
        ]
        
        return possiblePaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// Check if FFmpeg is available
    var hasFFmpeg: Bool {
        let ffmpegPaths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg"
        ]
        
        return ffmpegPaths.contains { FileManager.default.fileExists(atPath: $0) }
    }
    
    /// Get the best available RAW viewer
    var bestRAWViewer: String? {
        if hasCaptureOne {
            return "Capture One"
        } else if hasLightroom {
            return "Adobe Lightroom"
        } else if hasPhotos {
            return "Photos"
        } else if hasPreview {
            return "Preview"
        } else if hasFFmpeg {
            return "FFmpeg"
        }
        return nil
    }
    
    /// Extract RAW metadata using available tools
    func extractRAWMetadata(from url: URL) async -> RAWMetadata? {
        // Try FFmpeg first for detailed metadata
        if hasFFmpeg {
            return await extractMetadataWithFFmpeg(url)
        }
        
        // Try using Core Graphics for basic metadata
        return await extractMetadataWithCoreGraphics(url)
    }
    
    private func extractMetadataWithFFmpeg(_ url: URL) async -> RAWMetadata? {
        let ffmpegPath = "/usr/local/bin/ffmpeg"
        let systemFFmpegPath = "/opt/homebrew/bin/ffmpeg"
        
        let ffmpeg = FileManager.default.fileExists(atPath: ffmpegPath) ? ffmpegPath :
                     FileManager.default.fileExists(atPath: systemFFmpegPath) ? systemFFmpegPath : nil
        
        guard let ffmpegExecutable = ffmpeg else {
            return nil
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegExecutable)
        process.arguments = [
            "-i", url.path,
            "-f", "null",
            "-"
        ]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return parseRAWMetadataFromFFmpeg(output)
        } catch {
            print("DEBUG: RAWSupport - FFmpeg error: \(error)")
            return nil
        }
    }
    
    private func extractMetadataWithCoreGraphics(_ url: URL) async -> RAWMetadata? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        var resolution = "Unknown"
        var colorDepth = "Unknown"
        var colorSpace = "Unknown"
        var format = "RAW"
        
        // Get dimensions
        if let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
           let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            resolution = "\(width) x \(height)"
        }
        
        // Get color depth
        if let depth = properties[kCGImagePropertyDepth as String] as? Int {
            colorDepth = "\(depth) bit"
        }
        
        // Get color space
        if let colorModel = properties[kCGImagePropertyColorModel as String] as? String {
            colorSpace = colorModel
        }
        
        // Get format
        if let formatDescription = properties[kCGImagePropertyTIFFCompression as String] as? Int {
            format = "RAW (Compression \(formatDescription))"
        }
        
        return RAWMetadata(
            resolution: resolution,
            colorDepth: colorDepth,
            colorSpace: colorSpace,
            format: format
        )
    }
    
    private func parseRAWMetadataFromFFmpeg(_ output: String) -> RAWMetadata? {
        let lines = output.components(separatedBy: .newlines)
        
        var resolution = "Unknown"
        let colorDepth = "Unknown"
        var colorSpace = "Unknown"
        var format = "RAW"
        
        for line in lines {
            if line.contains("Video:") {
                // Extract resolution
                if let resolutionMatch = line.range(of: #"(\d{2,4}x\d{2,4})"#, options: .regularExpression) {
                    resolution = String(line[resolutionMatch])
                }
                
                // Extract format
                if let formatMatch = line.range(of: #"Video:\s+([^,\s]+)"#, options: .regularExpression) {
                    let formatString = String(line[formatMatch])
                    if let formatName = formatString.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) {
                        format = formatName
                    }
                }
            }
            
            // Extract color information
            if line.contains("Color") {
                if let colorMatch = line.range(of: #"([^,\s]+)"#, options: .regularExpression) {
                    colorSpace = String(line[colorMatch])
                }
            }
        }
        
        return RAWMetadata(
            resolution: resolution,
            colorDepth: colorDepth,
            colorSpace: colorSpace,
            format: format
        )
    }
    
    /// Convert RAW file to JPEG using FFmpeg
    func convertRAWToJPEG(_ inputURL: URL) async -> URL? {
        guard hasFFmpeg else { return nil }
        
        let ffmpegPath = "/usr/local/bin/ffmpeg"
        let systemFFmpegPath = "/opt/homebrew/bin/ffmpeg"
        
        let ffmpeg = FileManager.default.fileExists(atPath: ffmpegPath) ? ffmpegPath :
                     FileManager.default.fileExists(atPath: systemFFmpegPath) ? systemFFmpegPath : nil
        
        guard let ffmpegExecutable = ffmpeg else {
            return nil
        }
        
        // Create temporary output file
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("\(UUID().uuidString).jpg")
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegExecutable)
        process.arguments = [
            "-i", inputURL.path,
            "-q:v", "2", // High quality
            "-y", // Overwrite output file
            outputURL.path
        ]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputURL.path) {
                return outputURL
            }
        } catch {
            print("DEBUG: RAWSupport - FFmpeg conversion error: \(error)")
        }
        
        return nil
    }
    
    /// Open RAW file with the best available viewer
    func openRAWFile(_ url: URL) {
        // Try Capture One first (professional RAW editor)
        if hasCaptureOne {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [
                "-a", "Capture One",
                url.path
            ]
            
            do {
                try process.run()
                return
            } catch {
                print("DEBUG: RAWSupport - Failed to open with Capture One: \(error)")
            }
        }
        
        // Try Adobe Lightroom
        if hasLightroom {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [
                "-a", "Adobe Lightroom",
                url.path
            ]
            
            do {
                try process.run()
                return
            } catch {
                print("DEBUG: RAWSupport - Failed to open with Lightroom: \(error)")
            }
        }
        
        // Try Photos.app
        if hasPhotos {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [
                "-a", "Photos",
                url.path
            ]
            
            do {
                try process.run()
                return
            } catch {
                print("DEBUG: RAWSupport - Failed to open with Photos: \(error)")
            }
        }
        
        // Fallback to Preview.app
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-a", "Preview",
            url.path
        ]
        
        do {
            try process.run()
        } catch {
            print("DEBUG: RAWSupport - Failed to open with Preview: \(error)")
            // Final fallback to default application
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - RAW Metadata Structure

struct RAWMetadata {
    let resolution: String
    let colorDepth: String
    let colorSpace: String
    let format: String
} 

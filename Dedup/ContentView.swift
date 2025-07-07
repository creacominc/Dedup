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
    @State private var selectedTab = 0
    
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
                                FileRowView(file: file)
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
                        if let width = file.width, let height = file.height {
                            Text("Dimensions: \(file.formattedDimensions)")
                            Text("Aspect Ratio: \(file.formattedAspectRatio)")
                        }
                        
                        if let duration = file.duration {
                            Text("Duration: \(file.formattedDuration)")
                        }
                        
                        if let frameRate = file.frameRate {
                            Text("Frame Rate: \(file.formattedFrameRate)")
                        }
                        
                        if let bitRate = file.bitRate {
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
                        PhotoView(file: file)
                            .id(file.id)
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
        
        player = nil
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
        
        player = nil
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
            
            // Audio controls - only show if player exists
            if player != nil {
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
            }
        }
        .padding(.all, 10) // Reduced padding for more content space
        .onAppear {
            print("DEBUG: AudioView appeared for file: \(file.displayName)")
            setupPlayer()
        }
        .onDisappear {
            print("DEBUG: AudioView disappeared for file: \(file.displayName)")
            cleanupPlayer()
        }
    }
    
    private func setupPlayer() {
        print("DEBUG: AudioView - Setting up player for: \(file.displayName)")
        player = AVPlayer(url: file.url)
        
        // Get duration
        let asset = AVURLAsset(url: file.url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                await MainActor.run {
                    self.duration = CMTimeGetSeconds(duration)
                    print("DEBUG: AudioView - Audio loaded successfully: \(file.displayName), duration: \(self.duration)")
                }
            } catch {
                print("DEBUG: AudioView - Error loading audio: \(error.localizedDescription)")
            }
        }
        
        // Setup timer for progress updates
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if let player = player {
                currentTime = CMTimeGetSeconds(player.currentTime())
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
        
        player = nil
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

struct SettingsView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedTab: Int
    
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
            
            // Show Start Processing button when both directories are selected but not processing
            if fileProcessor.sourceURL != nil && fileProcessor.targetURL != nil && !fileProcessor.isProcessing {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ready to Process")
                        .font(.headline)
                        .accessibilityIdentifier("label-readyToProcess")
                    
                    Button("Start Processing") {
                        Task {
                            await fileProcessor.startProcessing()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("button-startProcessing")
                }
            }
            
            // Show Processing button when processing is active
            if fileProcessor.isProcessing {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Processing")
                        .font(.headline)
                        .accessibilityIdentifier("label-processingHeader")
                    
                    Button("Processing...") {
                        // Button is disabled during processing
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                    .accessibilityIdentifier("button-processing")
                    
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
            }
            
            Spacer()
        }
        .padding()
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
                                Text("BRAW Video Not Supported")
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
                                Text("BRAW Video Not Available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("BRAW files require specialized software like DaVinci Resolve or Blackmagic RAW Player.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
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
                    print("DEBUG: BRAWVideoView showing 'not available' - \(file.displayName)")
                    print("DEBUG: BRAWVideoView state - player: \(player != nil), isLoading: \(isLoading), videoError: \(videoError ?? "none")")
                }
            }
        }
        .padding(.all, 10) // Reduced padding for more video space
        .background(Color.blue.opacity(0.1)) // Debug container background restored
        .onAppear {
            print("DEBUG: BRAWVideoView appeared for file: \(file.displayName)")
            print("DEBUG: BRAWVideoView blue background visible - \(file.displayName)")
            resetState()
            setupPlayer()
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
    }
    
    private func setupPlayer() {
        print("DEBUG: BRAWVideoView - Setting up player for: \(file.displayName)")
        isLoading = true
        
        // Clean up timer only, don't reset player yet
        timer?.invalidate()
        timer = nil
        
        // Add safety check for URL
        guard file.url.isFileURL else {
            print("DEBUG: BRAWVideoView - Invalid file URL: \(file.url)")
            videoError = "Invalid file URL"
            isLoading = false
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: file.url.path) else {
            print("DEBUG: BRAWVideoView - File does not exist: \(file.url.path)")
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
            print("DEBUG: BRAWVideoView - Player created for: \(file.displayName), player: \(self.player != nil)")
            
            // Verify player was created successfully
            guard self.player != nil else {
                print("DEBUG: BRAWVideoView - Failed to create player")
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
                print("DEBUG: BRAWVideoView - Player item failed to play")
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
                        print("DEBUG: BRAWVideoView - Video loaded successfully: \(file.displayName), duration: \(self.duration), player: \(self.player != nil)")
                    }
                } catch {
                    await MainActor.run {
                        self.videoError = "Could not load video duration: \(error.localizedDescription)"
                        self.isLoading = false
                        print("DEBUG: BRAWVideoView - Error loading video: \(error.localizedDescription)")
                    }
                }
            }
            
            // Set loading to false after a short delay to ensure player is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.player != nil && self.player?.currentItem != nil {
                    self.isLoading = false
                    print("DEBUG: BRAWVideoView - Player ready, setting loading to false")
                } else {
                    print("DEBUG: BRAWVideoView - Player not ready, showing error")
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
        
        player = nil
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
} 
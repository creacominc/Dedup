import SwiftUI
import AVKit
import AppKit

struct VideoView: View {
    let file: MediaFile
    //    let file: FileInfo
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
                                    NSWorkspace.shared.selectFile(file.fileUrl.path, inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path)
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
                                    NSWorkspace.shared.selectFile(file.fileUrl.path, inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path)
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
        guard file.fileUrl.isFileURL else {
            print("DEBUG: VideoView - Invalid file URL: \(file.fileUrl)")
            videoError = "Invalid file URL"
            isLoading = false
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: file.fileUrl.path) else {
            print("DEBUG: VideoView - File does not exist: \(file.fileUrl.path)")
            videoError = "File does not exist"
            isLoading = false
            return
        }
        
        // Try to create AVPlayer for video with error handling
        // Create the player on the main queue to avoid threading issues
        DispatchQueue.main.async {
            // Create AVPlayer with error handling
            let playerItem = AVPlayerItem(url: file.fileUrl)
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
                Task { @MainActor in
                    self.videoError = "Video failed to play"
                    self.isLoading = false
                }
            }
            
            // Get duration and set loading to false
            let asset = AVURLAsset(url: file.fileUrl)
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
                Task { @MainActor in
                    if self.player != nil && self.player?.currentItem != nil {
                        self.isLoading = false
                        print("DEBUG: VideoView - Player ready, setting loading to false")
                    } else {
                        print("DEBUG: VideoView - Player not ready, showing error")
                        self.videoError = "Failed to initialize video player"
                        self.isLoading = false
                    }
                }
            }
            
            // Setup timer for progress updates
            self.timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    if let player = self.player {
                        self.currentTime = CMTimeGetSeconds(player.currentTime())
                    }
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


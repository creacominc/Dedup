import SwiftUI
import AVKit
import AppKit

struct AudioView: View {
    let file: MediaFile
    //    let file: FileInfo
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
                        NSWorkspace.shared.selectFile(file.fileUrl.path, inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path)
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
        guard file.fileUrl.isFileURL else {
            print("DEBUG: AudioView - Invalid file URL: \(file.fileUrl)")
            audioError = "Invalid file URL"
            isLoading = false
            return
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: file.fileUrl.path) else {
            print("DEBUG: AudioView - File does not exist: \(file.fileUrl.path)")
            audioError = "File does not exist"
            isLoading = false
            return
        }
        
        // Create AVPlayer with error handling
        DispatchQueue.main.async {
            self.player = AVPlayer(url: file.fileUrl)
            print("DEBUG: AudioView - Player created for: \(file.displayName), player: \(self.player != nil)")
            
            // Verify player was created successfully
            guard self.player != nil else {
                print("DEBUG: AudioView - Failed to create player")
                self.audioError = "Failed to create audio player"
                self.isLoading = false
                return
            }
            
            // Get duration
            let asset = AVURLAsset(url: file.fileUrl)
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
        
        // MEMORY FIX: Explicitly release player and its item to free memory immediately
        // This is critical for freeing audio buffer memory
        if let currentPlayer = player {
            currentPlayer.replaceCurrentItem(with: nil)
            player = nil
        }
        
        print("DEBUG: AudioView - Player resources released")
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


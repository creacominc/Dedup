import SwiftUI
import AVKit
import AppKit

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
                Task { @MainActor in
                    self.tryAlternativeBRAWPlayback()
                }
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


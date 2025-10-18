import SwiftUI
import AVKit
import AppKit

struct FileDetailView: View
{
    let file: MediaFile
    //    let file: FileInfo
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?
    @State private var videoError: String?
    
    var body: some View
    {
        VStack(spacing: 0)
        {
            // File information header
            VStack(alignment: .leading, spacing: 8)
            {
                Text(file.displayName)
                    .font(.headline)
                    .lineLimit(1)
                
                // Basic file info
                HStack
                {
                    VStack(alignment: .leading, spacing: 4)
                    {
                        Text("Size: \(file.fileSize)")
                        //Text("Created: \(file.formattedCreationDate)")
                        Text("Type: \(file.mediaType.displayName)")
                    }
//                    
//                    Spacer()
//                    
//                    // Media-specific metadata
//                    VStack(alignment: .trailing, spacing: 4)
//                    {
//                        if file.width != nil && file.height != nil {
//                            Text("Dimensions: \(file.formattedDimensions)")
//                            Text("Aspect Ratio: \(file.formattedAspectRatio)")
//                        }
//                        
//                        if file.duration != nil {
//                            Text("Duration: \(file.formattedDuration)")
//                        }
//                        
//                        if file.frameRate != nil {
//                            Text("Frame Rate: \(file.formattedFrameRate)")
//                        }
//                        
//                        if file.bitRate != nil {
//                            Text("Bit Rate: \(file.formattedBitRate)")
//                        }
//                        
//                        if let codec = file.codec {
//                            Text("Codec: \(codec)")
//                        }
//                        
//                        if let colorDepth = file.colorDepth {
//                            Text("Color Depth: \(colorDepth) bit")
//                        }
//                        
//                        if let colorSpace = file.colorSpace {
//                            Text("Color Space: \(colorSpace)")
//                        }
//                        
//                        if file.mediaType == .video || file.mediaType == .audio {
//                            Text("Audio: \(file.formattedAudioInfo)")
//                        }
//                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Show in Finder button
                Button(action: {
                    NSWorkspace.shared.selectFile(file.fileUrl.path, inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path)
                }) {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
//            
//            Divider()
//            
//            // Media content
//            Group
//            {
//                if !file.isViewable
//                {
//                    UnsupportedFileView(file: file)
//                        .id(file.id)
//                        .onAppear {
//                            print("DEBUG: File not viewable - \(file.displayName), mediaType: \(file.mediaType.rawValue), isViewable: \(file.isViewable)")
//                        }
//                }
//                else
//                {
//                    switch file.mediaType
//                    {
//                    case .photo:
//                        if file.isRAWFile {
//                            RAWImageView(file: file)
//                                .id(file.id)
//                        } else {
//                            PhotoView(file: file)
//                                .id(file.id)
//                        }
//                    case .video:
//                        if file.fileExtension.lowercased() == "braw" {
//                            BRAWVideoView(file: file, player: $player, isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, timer: $timer)
//                                .id(file.id)
//                        } else {
//                            VideoView(file: file, player: $player, isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, timer: $timer)
//                                .id(file.id)
//                        }
//                    case .audio:
//                        AudioView(file: file, player: $player, isPlaying: $isPlaying, currentTime: $currentTime, duration: $duration, timer: $timer)
//                            .id(file.id)
//                    case .unsupported:
//                        UnsupportedFileView(file: file)
//                            .id(file.id)
//                            .onAppear {
//                                print("DEBUG: Unsupported media type - \(file.displayName), mediaType: \(file.mediaType.rawValue)")
//                            }
//                    }
//                }
//            }
//            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .background(Color.green.opacity(0.1)) // Debug media content area restored
//            .onAppear {
//                print("DEBUG: Media content area appeared for: \(file.displayName)")
//                print("DEBUG: Media content area green background visible - \(file.displayName)")
//            }
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


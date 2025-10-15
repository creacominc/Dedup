import Foundation
import AppKit

// MARK: - BRAW Metadata Structure
struct BRAWMetadata {
    let resolution: String
    let frameRate: String
    let codec: String
    let duration: String
}

// MARK: - BRAW Support Utilities
@MainActor
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


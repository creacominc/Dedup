import Foundation
import AppKit
import ImageIO

// MARK: - RAW Metadata Structure
struct RAWMetadata {
    let resolution: String
    let colorDepth: String
    let colorSpace: String
    let format: String
}

// MARK: - RAW Image Support Utilities
@MainActor
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


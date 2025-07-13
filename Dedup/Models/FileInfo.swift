import Foundation
import CryptoKit
import AVFoundation
import ImageIO

/// Tracks checksum computation status for efficient processing
struct ChecksumStatus: Codable {
    var checksum1KB: String?
    var checksum1GB: String?
    var checksum4GB: String?
    var checksum12GB: String?
    var checksum64GB: String?
    var checksum128GB: String?
    var checksumFull: String?
    
    var hasComputed1KB: Bool { checksum1KB != nil }
    var hasComputed1GB: Bool { checksum1GB != nil }
    var hasComputed4GB: Bool { checksum4GB != nil }
    var hasComputed12GB: Bool { checksum12GB != nil }
    var hasComputed64GB: Bool { checksum64GB != nil }
    var hasComputed128GB: Bool { checksum128GB != nil }
    var hasComputedFull: Bool { checksumFull != nil }
}

/// Represents a media file with metadata for deduplication
struct FileInfo: Identifiable, Hashable, Codable {
    var id = UUID()
    let url: URL
    let name: String
    let size: Int64
    let creationDate: Date
    let modificationDate: Date
    let mediaType: MediaType
    let fileExtension: String
    
    // Checksums for different file portions - now lazy computed
    var checksumStatus = ChecksumStatus()
    
    // Media metadata
    var width: Int?
    var height: Int?
    var duration: Double?
    var codec: String?
    var bitRate: Int?
    var frameRate: Double?
    var colorDepth: Int?
    var colorSpace: String?
    var audioCodec: String?
    var audioChannels: Int?
    var audioSampleRate: Double?
    
    // Computed properties for checksums (lazy access)
    var checksum1KB: String? { checksumStatus.checksum1KB }
    var checksum1GB: String? { checksumStatus.checksum1GB }
    var checksum4GB: String? { checksumStatus.checksum4GB }
    var checksum12GB: String? { checksumStatus.checksum12GB }
    var checksum64GB: String? { checksumStatus.checksum64GB }
    var checksum128GB: String? { checksumStatus.checksum128GB }
    var checksumFull: String? { checksumStatus.checksumFull }
    
    // Computed properties
    var displayName: String {
        return url.lastPathComponent
    }
    
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedCreationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "Unknown" }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "Unknown"
    }
    
    var formattedDimensions: String {
        guard let width = width, let height = height else { return "Unknown" }
        return "\(width) × \(height)"
    }
    
    var formattedAspectRatio: String {
        guard let width = width, let height = height, width > 0, height > 0 else { return "Unknown" }
        let gcd = greatestCommonDivisor(width, height)
        let aspectWidth = width / gcd
        let aspectHeight = height / gcd
        return "\(aspectWidth):\(aspectHeight)"
    }
    
    var formattedFrameRate: String {
        guard let frameRate = frameRate else { return "Unknown" }
        return String(format: "%.2f fps", frameRate)
    }
    
    var formattedBitRate: String {
        guard let bitRate = bitRate else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: Int64(bitRate), countStyle: .binary) + "/s"
    }
    
    var formattedAudioInfo: String {
        var parts: [String] = []
        
        if let audioCodec = audioCodec {
            parts.append(audioCodec)
        }
        
        if let audioChannels = audioChannels {
            parts.append("\(audioChannels) ch")
        }
        
        if let audioSampleRate = audioSampleRate {
            parts.append(String(format: "%.0f Hz", audioSampleRate))
        }
        
        return parts.isEmpty ? "Unknown" : parts.joined(separator: ", ")
    }
    
    var isViewable: Bool {
        return mediaType.isViewable
    }
    
    var isBRAWFile: Bool {
        return mediaType == .video && fileExtension.lowercased() == "braw"
    }
    
    var isRAWFile: Bool {
        let rawExtensions = ["cr2", "rw2", "raw", "dng", "arw", "nef", "orf", "rwz"]
        return mediaType == .photo && rawExtensions.contains(fileExtension.lowercased())
    }
    
    init(url: URL) throws {
        self.url = url
        self.name = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        
        guard let size = attributes[.size] as? Int64 else {
            throw FileError.invalidFileSize
        }
        self.size = size
        
        guard let creationDate = attributes[.creationDate] as? Date else {
            throw FileError.invalidCreationDate
        }
        self.creationDate = creationDate
        
        guard let modificationDate = attributes[.modificationDate] as? Date else {
            throw FileError.invalidModificationDate
        }
        self.modificationDate = modificationDate
        
        self.mediaType = MediaType.from(fileExtension: fileExtension)
    }
    
    // MARK: - Checksum Computation
    
    /// Computes all checksums for the file (legacy method - use computeChecksumIfNeeded for efficiency)
    mutating func computeChecksums() async throws {
        print("🔍 [CHKSUM] Computing ALL checksums for \(displayName) (\(formattedSize))")
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        
        // Compute 1KB checksum
        if size >= 1024 {
            if let data = try fileHandle.read(upToCount: 1024) {
                checksumStatus.checksum1KB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                print("🔍 [CHKSUM] Computed 1KB checksum for \(displayName)")
            }
        }
        
        // Compute 1GB checksum
        if size >= 1 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 1 * 1024 * 1024 * 1024) {
                checksumStatus.checksum1GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                print("🔍 [CHKSUM] Computed 1GB checksum for \(displayName)")
            }
        }
        
        // Compute 4GB checksum
        if size >= 4 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 4 * 1024 * 1024 * 1024) {
                checksumStatus.checksum4GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                print("🔍 [CHKSUM] Computed 4GB checksum for \(displayName)")
            }
        }
        
        // Compute 12GB checksum
        if size >= 12 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 12 * 1024 * 1024 * 1024) {
                checksumStatus.checksum12GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                print("🔍 [CHKSUM] Computed 12GB checksum for \(displayName)")
            }
        }
        
        // Compute 64GB checksum
        if size >= 64 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 64 * 1024 * 1024 * 1024) {
                checksumStatus.checksum64GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                print("🔍 [CHKSUM] Computed 64GB checksum for \(displayName)")
            }
        }
        
        // Compute 128GB checksum
        if size >= 128 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 128 * 1024 * 1024 * 1024) {
                checksumStatus.checksum128GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                print("🔍 [CHKSUM] Computed 128GB checksum for \(displayName)")
            }
        }
        
        // Compute full file checksum
        try fileHandle.seek(toOffset: 0)
        if let data = try fileHandle.readToEnd() {
            checksumStatus.checksumFull = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            print("🔍 [CHKSUM] Computed FULL checksum for \(displayName)")
        }
    }
    
    /// Efficiently computes checksums only when needed for comparison
    mutating func computeChecksumIfNeeded(for size: Int64) async throws -> String? {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        
        switch size {
        case 1024:
            if !checksumStatus.hasComputed1KB {
                print("🔍 [CHKSUM] Computing 1KB checksum for \(displayName) (size: \(formattedSize)) - reading 1,024 bytes")
                if let data = try fileHandle.read(upToCount: 1024) {
                    checksumStatus.checksum1KB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                    print("🔍 [CHKSUM] ✅ Computed 1KB checksum for \(displayName) (1,024 bytes read)")
                }
            } else {
                print("🔍 [CHKSUM] ✅ Using cached 1KB checksum for \(displayName)")
            }
            return checksumStatus.checksum1KB
            
        case 1 * 1024 * 1024 * 1024:
            if !checksumStatus.hasComputed1GB {
                print("🔍 [CHKSUM] Computing 1GB checksum for \(displayName) (size: \(formattedSize)) - reading 1,073,741,824 bytes")
                if let data = try fileHandle.read(upToCount: 1 * 1024 * 1024 * 1024) {
                    checksumStatus.checksum1GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                    print("🔍 [CHKSUM] ✅ Computed 1GB checksum for \(displayName) (1,073,741,824 bytes read)")
                }
            } else {
                print("🔍 [CHKSUM] ✅ Using cached 1GB checksum for \(displayName)")
            }
            return checksumStatus.checksum1GB
            
        case 4 * 1024 * 1024 * 1024:
            if !checksumStatus.hasComputed4GB {
                print("🔍 [CHKSUM] Computing 4GB checksum for \(displayName) (size: \(formattedSize)) - reading 4,294,967,296 bytes")
                if let data = try fileHandle.read(upToCount: 4 * 1024 * 1024 * 1024) {
                    checksumStatus.checksum4GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                    print("🔍 [CHKSUM] ✅ Computed 4GB checksum for \(displayName) (4,294,967,296 bytes read)")
                }
            } else {
                print("🔍 [CHKSUM] ✅ Using cached 4GB checksum for \(displayName)")
            }
            return checksumStatus.checksum4GB
            
        case 12 * 1024 * 1024 * 1024:
            if !checksumStatus.hasComputed12GB {
                print("🔍 [CHKSUM] Computing 12GB checksum for \(displayName) (size: \(formattedSize)) - reading 12,884,901,888 bytes")
                if let data = try fileHandle.read(upToCount: 12 * 1024 * 1024 * 1024) {
                    checksumStatus.checksum12GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                    print("🔍 [CHKSUM] ✅ Computed 12GB checksum for \(displayName) (12,884,901,888 bytes read)")
                }
            } else {
                print("🔍 [CHKSUM] ✅ Using cached 12GB checksum for \(displayName)")
            }
            return checksumStatus.checksum12GB
            
        case 64 * 1024 * 1024 * 1024:
            if !checksumStatus.hasComputed64GB {
                print("🔍 [CHKSUM] Computing 64GB checksum for \(displayName) (size: \(formattedSize)) - reading 68,719,476,736 bytes")
                if let data = try fileHandle.read(upToCount: 64 * 1024 * 1024 * 1024) {
                    checksumStatus.checksum64GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                    print("🔍 [CHKSUM] ✅ Computed 64GB checksum for \(displayName) (68,719,476,736 bytes read)")
                }
            } else {
                print("🔍 [CHKSUM] ✅ Using cached 64GB checksum for \(displayName)")
            }
            return checksumStatus.checksum64GB
            
        case 128 * 1024 * 1024 * 1024:
            if !checksumStatus.hasComputed128GB {
                print("🔍 [CHKSUM] Computing 128GB checksum for \(displayName) (size: \(formattedSize)) - reading 137,438,953,472 bytes")
                if let data = try fileHandle.read(upToCount: 128 * 1024 * 1024 * 1024) {
                    checksumStatus.checksum128GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                    print("🔍 [CHKSUM] ✅ Computed 128GB checksum for \(displayName) (137,438,953,472 bytes read)")
                }
            } else {
                print("🔍 [CHKSUM] ✅ Using cached 128GB checksum for \(displayName)")
            }
            return checksumStatus.checksum128GB
            
        default:
            // Full file checksum
            if !checksumStatus.hasComputedFull {
                print("🔍 [CHKSUM] Computing FULL checksum for \(displayName) (size: \(formattedSize)) - reading \(size) bytes")
                if let data = try fileHandle.readToEnd() {
                    checksumStatus.checksumFull = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
                    print("🔍 [CHKSUM] ✅ Computed FULL checksum for \(displayName) (\(size) bytes read)")
                }
            } else {
                print("🔍 [CHKSUM] ✅ Using cached FULL checksum for \(displayName)")
            }
            return checksumStatus.checksumFull
        }
    }
    
    // MARK: - Metadata Extraction
    
    mutating func extractMetadata() async {
        switch mediaType {
        case .video:
            await extractVideoMetadata()
        case .photo:
            extractPhotoMetadata()
        case .audio:
            await extractAudioMetadata()
        case .unsupported:
            break
        }
    }
    
    private mutating func extractVideoMetadata() async {
        // For MKV files or when AVFoundation fails, try FFmpeg first
        if fileExtension.lowercased() == "mkv" {
            if await extractVideoMetadataWithFFmpeg() {
                return
            }
        }
        
        // Fallback to AVFoundation
        let asset = AVURLAsset(url: url)
        do {
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            if let videoTrack = videoTracks.first {
                let size = try await videoTrack.load(.naturalSize)
                width = Int(size.width)
                height = Int(size.height)
                let formatDescriptions = try await videoTrack.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    codec = String(describing: mediaSubType)
                }
                let frameRate = try await videoTrack.load(.nominalFrameRate)
                self.frameRate = Double(frameRate)
                let bitRate = try await videoTrack.load(.estimatedDataRate)
                self.bitRate = Int(bitRate)
            }
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if let audioTrack = audioTracks.first {
                let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    audioCodec = String(describing: mediaSubType)
                    if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                        audioChannels = Int(asbd.pointee.mChannelsPerFrame)
                        audioSampleRate = Double(asbd.pointee.mSampleRate)
                    }
                }
                let bitRate = try await audioTrack.load(.estimatedDataRate)
                self.bitRate = Int(bitRate)
            }
            let duration = try await asset.load(.duration)
            self.duration = duration.seconds
        } catch {
            print("Failed to extract video metadata with AVFoundation: \(error)")
            // If AVFoundation fails, try FFmpeg as fallback
            if await extractVideoMetadataWithFFmpeg() {
                return
            }
        }
    }
    
    private mutating func extractVideoMetadataWithFFmpeg() async -> Bool {
        let ffmpegPath = "/usr/local/bin/ffmpeg"
        let systemFFmpegPath = "/opt/homebrew/bin/ffmpeg"
        
        let ffmpeg = FileManager.default.fileExists(atPath: ffmpegPath) ? ffmpegPath :
                     FileManager.default.fileExists(atPath: systemFFmpegPath) ? systemFFmpegPath : nil
        
        guard let ffmpegExecutable = ffmpeg else {
            print("FFmpeg not found for metadata extraction")
            return false
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
            
            return parseVideoMetadataFromFFmpeg(output)
        } catch {
            print("Failed to run FFmpeg for metadata extraction: \(error)")
            return false
        }
    }
    
    private mutating func parseVideoMetadataFromFFmpeg(_ output: String) -> Bool {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Extract video resolution
            if line.contains("Video:") {
                if let resolutionMatch = line.range(of: #"(\d{2,4})x(\d{2,4})"#, options: .regularExpression) {
                    let resolutionString = String(line[resolutionMatch])
                    let components = resolutionString.components(separatedBy: "x")
                    if components.count == 2,
                       let width = Int(components[0]),
                       let height = Int(components[1]) {
                        self.width = width
                        self.height = height
                    }
                }
                
                // Extract frame rate
                if let frameRateMatch = line.range(of: #"(\d+(?:\.\d+)?)\s*fps"#, options: .regularExpression) {
                    let frameRateString = String(line[frameRateMatch])
                    if let fps = frameRateString.components(separatedBy: " ").first,
                       let frameRate = Double(fps) {
                        self.frameRate = frameRate
                    }
                }
                
                // Extract video codec
                if let codecMatch = line.range(of: #"Video:\s+([^,\s]+)"#, options: .regularExpression) {
                    let codecString = String(line[codecMatch])
                    if let codecName = codecString.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) {
                        self.codec = codecName
                    }
                }
                
                // Extract bit rate
                if let bitRateMatch = line.range(of: #"(\d+)\s*kb/s"#, options: .regularExpression) {
                    let bitRateString = String(line[bitRateMatch])
                    if let bitRate = bitRateString.components(separatedBy: " ").first,
                       let bitRateInt = Int(bitRate) {
                        self.bitRate = bitRateInt * 1000 // Convert to bits per second
                    }
                }
            }
            
            // Extract audio information
            if line.contains("Audio:") {
                // Extract audio codec
                if let audioCodecMatch = line.range(of: #"Audio:\s+([^,\s]+)"#, options: .regularExpression) {
                    let audioCodecString = String(line[audioCodecMatch])
                    if let audioCodecName = audioCodecString.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) {
                        self.audioCodec = audioCodecName
                    }
                }
                
                // Extract audio channels
                if let channelsMatch = line.range(of: #"(\d+)\s*ch"#, options: .regularExpression) {
                    let channelsString = String(line[channelsMatch])
                    if let channels = channelsString.components(separatedBy: " ").first,
                       let channelsInt = Int(channels) {
                        self.audioChannels = channelsInt
                    }
                }
                
                // Extract audio sample rate
                if let sampleRateMatch = line.range(of: #"(\d+)\s*Hz"#, options: .regularExpression) {
                    let sampleRateString = String(line[sampleRateMatch])
                    if let sampleRate = sampleRateString.components(separatedBy: " ").first,
                       let sampleRateDouble = Double(sampleRate) {
                        self.audioSampleRate = sampleRateDouble
                    }
                }
            }
            
            // Extract duration
            if line.contains("Duration:") {
                if let durationMatch = line.range(of: #"Duration:\s+(\d{2}):(\d{2}):(\d{2})\.(\d{2})"#, options: .regularExpression) {
                    let durationString = String(line[durationMatch])
                    let components = durationString.components(separatedBy: ":")
                    if components.count >= 4,
                       let hours = Double(components[0]),
                       let minutes = Double(components[1]),
                       let seconds = Double(components[2]),
                       let centiseconds = Double(components[3]) {
                        let totalSeconds = hours * 3600 + minutes * 60 + seconds + centiseconds / 100
                        self.duration = totalSeconds
                    }
                }
            }
        }
        
        // Return true if we successfully extracted at least some metadata
        return width != nil || height != nil || duration != nil || codec != nil
    }
    
    private mutating func extractPhotoMetadata() {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else { return }
        
        // Get dimensions
        if let width = properties[kCGImagePropertyPixelWidth as String] as? Int {
            self.width = width
        }
        if let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            self.height = height
        }
        
        // Get color depth
        if let depth = properties[kCGImagePropertyDepth as String] as? Int {
            colorDepth = depth
        }
        
        // Get color space
        if let colorSpace = properties[kCGImagePropertyColorModel as String] as? String {
            self.colorSpace = colorSpace
        }
        
        // Get codec/format
        if let format = properties[kCGImagePropertyTIFFCompression as String] as? Int {
            codec = "TIFF Compression \(format)"
        } else {
            codec = "Unknown"
        }
    }
    
    private mutating func extractAudioMetadata() async {
        // For problematic audio formats, try FFmpeg first
        let problematicAudioFormats = ["ogg", "flac", "wma"]
        if problematicAudioFormats.contains(fileExtension.lowercased()) {
            if await extractAudioMetadataWithFFmpeg() {
                return
            }
        }
        
        // Fallback to AVFoundation
        let asset = AVURLAsset(url: url)
        do {
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if let audioTrack = audioTracks.first {
                let formatDescriptions = try await audioTrack.load(.formatDescriptions)
                if let formatDescription = formatDescriptions.first {
                    let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDescription)
                    audioCodec = String(describing: mediaSubType)
                    if let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) {
                        audioChannels = Int(asbd.pointee.mChannelsPerFrame)
                        audioSampleRate = Double(asbd.pointee.mSampleRate)
                    }
                }
                let bitRate = try await audioTrack.load(.estimatedDataRate)
                self.bitRate = Int(bitRate)
            }
            let duration = try await asset.load(.duration)
            self.duration = duration.seconds
        } catch {
            print("Failed to extract audio metadata with AVFoundation: \(error)")
            // If AVFoundation fails, try FFmpeg as fallback
            if await extractAudioMetadataWithFFmpeg() {
                return
            }
        }
    }
    
    private mutating func extractAudioMetadataWithFFmpeg() async -> Bool {
        let ffmpegPath = "/usr/local/bin/ffmpeg"
        let systemFFmpegPath = "/opt/homebrew/bin/ffmpeg"
        
        let ffmpeg = FileManager.default.fileExists(atPath: ffmpegPath) ? ffmpegPath :
                     FileManager.default.fileExists(atPath: systemFFmpegPath) ? systemFFmpegPath : nil
        
        guard let ffmpegExecutable = ffmpeg else {
            print("FFmpeg not found for audio metadata extraction")
            return false
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
            
            return parseAudioMetadataFromFFmpeg(output)
        } catch {
            print("Failed to run FFmpeg for audio metadata extraction: \(error)")
            return false
        }
    }
    
    private mutating func parseAudioMetadataFromFFmpeg(_ output: String) -> Bool {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            // Extract audio information
            if line.contains("Audio:") {
                // Extract audio codec
                if let audioCodecMatch = line.range(of: #"Audio:\s+([^,\s]+)"#, options: .regularExpression) {
                    let audioCodecString = String(line[audioCodecMatch])
                    if let audioCodecName = audioCodecString.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) {
                        self.audioCodec = audioCodecName
                    }
                }
                
                // Extract audio channels
                if let channelsMatch = line.range(of: #"(\d+)\s*ch"#, options: .regularExpression) {
                    let channelsString = String(line[channelsMatch])
                    if let channels = channelsString.components(separatedBy: " ").first,
                       let channelsInt = Int(channels) {
                        self.audioChannels = channelsInt
                    }
                }
                
                // Extract audio sample rate
                if let sampleRateMatch = line.range(of: #"(\d+)\s*Hz"#, options: .regularExpression) {
                    let sampleRateString = String(line[sampleRateMatch])
                    if let sampleRate = sampleRateString.components(separatedBy: " ").first,
                       let sampleRateDouble = Double(sampleRate) {
                        self.audioSampleRate = sampleRateDouble
                    }
                }
                
                // Extract bit rate
                if let bitRateMatch = line.range(of: #"(\d+)\s*kb/s"#, options: .regularExpression) {
                    let bitRateString = String(line[bitRateMatch])
                    if let bitRate = bitRateString.components(separatedBy: " ").first,
                       let bitRateInt = Int(bitRate) {
                        self.bitRate = bitRateInt * 1000 // Convert to bits per second
                    }
                }
            }
            
            // Extract duration
            if line.contains("Duration:") {
                if let durationMatch = line.range(of: #"Duration:\s+(\d{2}):(\d{2}):(\d{2})\.(\d{2})"#, options: .regularExpression) {
                    let durationString = String(line[durationMatch])
                    let components = durationString.components(separatedBy: ":")
                    if components.count >= 4,
                       let hours = Double(components[0]),
                       let minutes = Double(components[1]),
                       let seconds = Double(components[2]),
                       let centiseconds = Double(components[3]) {
                        let totalSeconds = hours * 3600 + minutes * 60 + seconds + centiseconds / 100
                        self.duration = totalSeconds
                    }
                }
            }
        }
        
        // Return true if we successfully extracted at least some metadata
        return duration != nil || audioCodec != nil || audioChannels != nil || audioSampleRate != nil
    }
    
    // MARK: - Duplicate Detection
    
    func isLikelyDuplicate(of other: FileInfo) -> Bool {
        // Use robust base name extraction
        let baseName = url.deletingPathExtension().lastPathComponent
        let otherBaseName = other.url.deletingPathExtension().lastPathComponent
        return baseName.lowercased() == otherBaseName.lowercased()
    }
    
    func isDefinitelyDuplicate(of other: FileInfo) -> Bool {
        guard size == other.size else { 
            print("🔍 [COMPARE] Size mismatch: \(displayName) (\(formattedSize)) vs \(other.displayName) (\(other.formattedSize))")
            return false 
        }
        
        print("🔍 [COMPARE] Comparing \(displayName) vs \(other.displayName) (same size: \(formattedSize))")
        
        // Compare checksums progressively - this is now handled by the new efficient method
        return false // This will be replaced by the new async method
    }
    
    /// Efficiently compares files with lazy checksum computation
    /// Returns (isDuplicate, mutatedTargetFile)
    mutating func isDefinitelyDuplicateEfficientWithTarget(of targetFile: FileInfo) async -> (Bool, FileInfo) {
        guard size == targetFile.size else { 
            print("🔍 [COMPARE] Size mismatch: \(displayName) (\(formattedSize)) vs \(targetFile.displayName) (\(targetFile.formattedSize))")
            return (false, targetFile)
        }
        
        print("🔍 [COMPARE] Comparing \(displayName) vs \(targetFile.displayName) (same size: \(formattedSize))")
        
        // Create a mutable copy of the target file to store its checksums
        var mutableTargetFile = targetFile
        
        // Compare 1KB checksums first
        do {
            let myChecksum1KB = try await computeChecksumIfNeeded(for: 1024)
            let targetChecksum1KB = try await mutableTargetFile.computeChecksumIfNeeded(for: 1024)
            
            if myChecksum1KB != targetChecksum1KB {
                print("🔍 [COMPARE] ❌ 1KB checksum mismatch: \(displayName) vs \(targetFile.displayName)")
                return (false, mutableTargetFile)
            }
            print("🔍 [COMPARE] ✅ 1KB checksums match: \(displayName) vs \(targetFile.displayName)")
        } catch {
            print("🔍 [COMPARE] ❌ Error computing 1KB checksums: \(error)")
            return (false, mutableTargetFile)
        }
        
        // Compare 1GB checksums if file is large enough
        if size >= 1 * 1024 * 1024 * 1024 {
            do {
                let myChecksum1GB = try await computeChecksumIfNeeded(for: 1 * 1024 * 1024 * 1024)
                let targetChecksum1GB = try await mutableTargetFile.computeChecksumIfNeeded(for: 1 * 1024 * 1024 * 1024)
                
                if myChecksum1GB != targetChecksum1GB {
                    print("🔍 [COMPARE] ❌ 1GB checksum mismatch: \(displayName) vs \(targetFile.displayName)")
                    return (false, mutableTargetFile)
                }
                print("🔍 [COMPARE] ✅ 1GB checksums match: \(displayName) vs \(targetFile.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 1GB checksums: \(error)")
                return (false, mutableTargetFile)
            }
        }
        
        // Compare 4GB checksums if file is large enough
        if size >= 4 * 1024 * 1024 * 1024 {
            do {
                let myChecksum4GB = try await computeChecksumIfNeeded(for: 4 * 1024 * 1024 * 1024)
                let targetChecksum4GB = try await mutableTargetFile.computeChecksumIfNeeded(for: 4 * 1024 * 1024 * 1024)
                
                if myChecksum4GB != targetChecksum4GB {
                    print("🔍 [COMPARE] ❌ 4GB checksum mismatch: \(displayName) vs \(targetFile.displayName)")
                    return (false, mutableTargetFile)
                }
                print("🔍 [COMPARE] ✅ 4GB checksums match: \(displayName) vs \(targetFile.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 4GB checksums: \(error)")
                return (false, mutableTargetFile)
            }
        }
        
        // Compare 12GB checksums if file is large enough
        if size >= 12 * 1024 * 1024 * 1024 {
            do {
                let myChecksum12GB = try await computeChecksumIfNeeded(for: 12 * 1024 * 1024 * 1024)
                let targetChecksum12GB = try await mutableTargetFile.computeChecksumIfNeeded(for: 12 * 1024 * 1024 * 1024)
                
                if myChecksum12GB != targetChecksum12GB {
                    print("🔍 [COMPARE] ❌ 12GB checksum mismatch: \(displayName) vs \(targetFile.displayName)")
                    return (false, mutableTargetFile)
                }
                print("🔍 [COMPARE] ✅ 12GB checksums match: \(displayName) vs \(targetFile.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 12GB checksums: \(error)")
                return (false, mutableTargetFile)
            }
        }
        
        // Compare 64GB checksums if file is large enough
        if size >= 64 * 1024 * 1024 * 1024 {
            do {
                let myChecksum64GB = try await computeChecksumIfNeeded(for: 64 * 1024 * 1024 * 1024)
                let targetChecksum64GB = try await mutableTargetFile.computeChecksumIfNeeded(for: 64 * 1024 * 1024 * 1024)
                
                if myChecksum64GB != targetChecksum64GB {
                    print("🔍 [COMPARE] ❌ 64GB checksum mismatch: \(displayName) vs \(targetFile.displayName)")
                    return (false, mutableTargetFile)
                }
                print("🔍 [COMPARE] ✅ 64GB checksums match: \(displayName) vs \(targetFile.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 64GB checksums: \(error)")
                return (false, mutableTargetFile)
            }
        }
        
        // Compare 128GB checksums if file is large enough
        if size >= 128 * 1024 * 1024 * 1024 {
            do {
                let myChecksum128GB = try await computeChecksumIfNeeded(for: 128 * 1024 * 1024 * 1024)
                let targetChecksum128GB = try await mutableTargetFile.computeChecksumIfNeeded(for: 128 * 1024 * 1024 * 1024)
                
                if myChecksum128GB != targetChecksum128GB {
                    print("🔍 [COMPARE] ❌ 128GB checksum mismatch: \(displayName) vs \(targetFile.displayName)")
                    return (false, mutableTargetFile)
                }
                print("🔍 [COMPARE] ✅ 128GB checksums match: \(displayName) vs \(targetFile.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 128GB checksums: \(error)")
                return (false, mutableTargetFile)
            }
        }
        
        // Finally compare full checksums
        do {
            let myChecksumFull = try await computeChecksumIfNeeded(for: size)
            let targetChecksumFull = try await mutableTargetFile.computeChecksumIfNeeded(for: size)
            
            if myChecksumFull != targetChecksumFull {
                print("🔍 [COMPARE] ❌ FULL checksum mismatch: \(displayName) vs \(targetFile.displayName)")
                return (false, mutableTargetFile)
            }
            print("🔍 [COMPARE] ✅ FULL checksums match: \(displayName) vs \(targetFile.displayName)")
            print("🔍 [COMPARE] 🎉 DUPLICATE CONFIRMED: \(displayName) vs \(targetFile.displayName)")
            return (true, mutableTargetFile)
        } catch {
            print("🔍 [COMPARE] ❌ Error computing FULL checksums: \(error)")
            return (false, mutableTargetFile)
        }
    }
    
    /// Efficiently compares files with lazy checksum computation
    mutating func isDefinitelyDuplicateEfficient(of other: FileInfo) async -> Bool {
        guard size == other.size else { 
            print("🔍 [COMPARE] Size mismatch: \(displayName) (\(formattedSize)) vs \(other.displayName) (\(other.formattedSize))")
            return false 
        }
        
        print("🔍 [COMPARE] Comparing \(displayName) vs \(other.displayName) (same size: \(formattedSize))")
        
        // Create a single mutable copy of the other file to store its checksums
        var mutableOther = other
        
        // Compare 1KB checksums first
        do {
            let myChecksum1KB = try await computeChecksumIfNeeded(for: 1024)
            let otherChecksum1KB = try await mutableOther.computeChecksumIfNeeded(for: 1024)
            
            if myChecksum1KB != otherChecksum1KB {
                print("🔍 [COMPARE] ❌ 1KB checksum mismatch: \(displayName) vs \(other.displayName)")
                return false
            }
            print("🔍 [COMPARE] ✅ 1KB checksums match: \(displayName) vs \(other.displayName)")
        } catch {
            print("🔍 [COMPARE] ❌ Error computing 1KB checksums: \(error)")
            return false
        }
        
        // Compare 1GB checksums if file is large enough
        if size >= 1 * 1024 * 1024 * 1024 {
            do {
                let myChecksum1GB = try await computeChecksumIfNeeded(for: 1 * 1024 * 1024 * 1024)
                let otherChecksum1GB = try await mutableOther.computeChecksumIfNeeded(for: 1 * 1024 * 1024 * 1024)
                
                if myChecksum1GB != otherChecksum1GB {
                    print("🔍 [COMPARE] ❌ 1GB checksum mismatch: \(displayName) vs \(other.displayName)")
                    return false
                }
                print("🔍 [COMPARE] ✅ 1GB checksums match: \(displayName) vs \(other.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 1GB checksums: \(error)")
                return false
            }
        }
        
        // Compare 4GB checksums if file is large enough
        if size >= 4 * 1024 * 1024 * 1024 {
            do {
                let myChecksum4GB = try await computeChecksumIfNeeded(for: 4 * 1024 * 1024 * 1024)
                let otherChecksum4GB = try await mutableOther.computeChecksumIfNeeded(for: 4 * 1024 * 1024 * 1024)
                
                if myChecksum4GB != otherChecksum4GB {
                    print("🔍 [COMPARE] ❌ 4GB checksum mismatch: \(displayName) vs \(other.displayName)")
                    return false
                }
                print("🔍 [COMPARE] ✅ 4GB checksums match: \(displayName) vs \(other.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 4GB checksums: \(error)")
                return false
            }
        }
        
        // Compare 12GB checksums if file is large enough
        if size >= 12 * 1024 * 1024 * 1024 {
            do {
                let myChecksum12GB = try await computeChecksumIfNeeded(for: 12 * 1024 * 1024 * 1024)
                let otherChecksum12GB = try await mutableOther.computeChecksumIfNeeded(for: 12 * 1024 * 1024 * 1024)
                
                if myChecksum12GB != otherChecksum12GB {
                    print("🔍 [COMPARE] ❌ 12GB checksum mismatch: \(displayName) vs \(other.displayName)")
                    return false
                }
                print("🔍 [COMPARE] ✅ 12GB checksums match: \(displayName) vs \(other.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 12GB checksums: \(error)")
                return false
            }
        }
        
        // Compare 64GB checksums if file is large enough
        if size >= 64 * 1024 * 1024 * 1024 {
            do {
                let myChecksum64GB = try await computeChecksumIfNeeded(for: 64 * 1024 * 1024 * 1024)
                let otherChecksum64GB = try await mutableOther.computeChecksumIfNeeded(for: 64 * 1024 * 1024 * 1024)
                
                if myChecksum64GB != otherChecksum64GB {
                    print("🔍 [COMPARE] ❌ 64GB checksum mismatch: \(displayName) vs \(other.displayName)")
                    return false
                }
                print("🔍 [COMPARE] ✅ 64GB checksums match: \(displayName) vs \(other.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 64GB checksums: \(error)")
                return false
            }
        }
        
        // Compare 128GB checksums if file is large enough
        if size >= 128 * 1024 * 1024 * 1024 {
            do {
                let myChecksum128GB = try await computeChecksumIfNeeded(for: 128 * 1024 * 1024 * 1024)
                let targetChecksum128GB = try await mutableOther.computeChecksumIfNeeded(for: 128 * 1024 * 1024 * 1024)
                
                if myChecksum128GB != targetChecksum128GB {
                    print("🔍 [COMPARE] ❌ 128GB checksum mismatch: \(displayName) vs \(other.displayName)")
                    return false
                }
                print("🔍 [COMPARE] ✅ 128GB checksums match: \(displayName) vs \(other.displayName)")
            } catch {
                print("🔍 [COMPARE] ❌ Error computing 128GB checksums: \(error)")
                return false
            }
        }
        
        // Finally compare full checksums
        do {
            let myChecksumFull = try await computeChecksumIfNeeded(for: size)
            let otherChecksumFull = try await mutableOther.computeChecksumIfNeeded(for: size)
            
            if myChecksumFull != otherChecksumFull {
                print("🔍 [COMPARE] ❌ FULL checksum mismatch: \(displayName) vs \(other.displayName)")
                return false
            }
            print("🔍 [COMPARE] ✅ FULL checksums match: \(displayName) vs \(other.displayName)")
            print("🔍 [COMPARE] 🎉 DUPLICATE CONFIRMED: \(displayName) vs \(other.displayName)")
            return true
        } catch {
            print("🔍 [COMPARE] ❌ Error computing FULL checksums: \(error)")
            return false
        }
    }
    
    // MARK: - Quality Comparison
    
    func isHigherQuality(than other: FileInfo) -> Bool {
        // First compare media type quality scores
        if mediaType.qualityScore != other.mediaType.qualityScore {
            return mediaType.qualityScore > other.mediaType.qualityScore
        }
        
        // If same media type, compare file extensions based on quality preferences
        let myExtensionIndex = mediaType.qualityPreferences.firstIndex(of: fileExtension.lowercased()) ?? Int.max
        let otherExtensionIndex = other.mediaType.qualityPreferences.firstIndex(of: other.fileExtension.lowercased()) ?? Int.max
        
        // Lower index means higher quality (preferred format)
        return myExtensionIndex < otherExtensionIndex
    }
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
    
    static func == (lhs: FileInfo, rhs: FileInfo) -> Bool {
        return lhs.url == rhs.url
    }
    
    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        var x = a
        var y = b
        while y != 0 {
            let temp = y
            y = x % y
            x = temp
        }
        return x
    }
}

// MARK: - Media Type Enum

enum MediaType: String, CaseIterable, Codable {
    case photo
    case video
    case audio
    case unsupported
    
    static func from(fileExtension: String) -> MediaType {
        let photoExtensions = ["jpeg", "jpg", "png", "gif", "bmp", "tiff", "tif", "psd", "cr2", "rw2", "raw", "dng", "arw", "nef", "orf", "rwz"]
        let videoExtensions = ["mov", "mp4", "avi", "mkv", "wmv", "flv", "webm", "m4v", "braw"]
        let audioExtensions = ["wav", "flac", "aac", "m4a", "mp3", "ogg", "wma"]
        
        let ext = fileExtension.lowercased()
        
        if photoExtensions.contains(ext) {
            return .photo
        } else if videoExtensions.contains(ext) {
            return .video
        } else if audioExtensions.contains(ext) {
            return .audio
        } else {
            return .unsupported // Default to unsupported for unknown extensions
        }
    }
    
    var qualityPreferences: [String] {
        switch self {
        case .photo:
            return ["cr2", "rw2", "raw", "dng", "arw", "nef", "orf", "rwz", "tiff", "tif", "psd", "jpeg", "jpg", "png", "bmp"]
        case .video:
            return ["braw", "mov", "mp4", "avi", "mkv", "wmv", "flv", "webm"]
        case .audio:
            return ["wav", "flac", "aac", "m4a", "mp3", "ogg"]
        case .unsupported:
            return []
        }
    }
    
    var qualityScore: Int {
        switch self {
        case .photo:
            return 3
        case .video:
            return 2
        case .audio:
            return 1
        case .unsupported:
            return 0
        }
    }
    
    var displayName: String {
        switch self {
        case .photo:
            return "Photos"
        case .video:
            return "Videos"
        case .audio:
            return "Audio"
        case .unsupported:
            return "Unsupported"
        }
    }
    
    var isViewable: Bool {
        switch self {
        case .photo:
            return true
        case .video:
            return true
        case .audio:
            return true
        case .unsupported:
            return false
        }
    }
}

// MARK: - File Errors

enum FileError: Error, LocalizedError {
    case invalidFileSize
    case invalidCreationDate
    case invalidModificationDate
    case fileNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidFileSize:
            return "Invalid file size"
        case .invalidCreationDate:
            return "Invalid creation date"
        case .invalidModificationDate:
            return "Invalid modification date"
        case .fileNotFound:
            return "File not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
} 
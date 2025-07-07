import Foundation
import CryptoKit
import AVFoundation
import ImageIO

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
    
    // Checksums for different file portions
    var checksum1KB: String?
    var checksum4GB: String?
    var checksum12GB: String?
    var checksum64GB: String?
    var checksum128GB: String?
    var checksumFull: String?
    
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
    
    mutating func computeChecksums() async throws {
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { try? fileHandle.close() }
        
        // Compute 1KB checksum
        if size >= 1024 {
            if let data = try fileHandle.read(upToCount: 1024) {
                checksum1KB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            }
        }
        
        // Compute 4GB checksum
        if size >= 4 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 4 * 1024 * 1024 * 1024) {
                checksum4GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            }
        }
        
        // Compute 12GB checksum
        if size >= 12 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 12 * 1024 * 1024 * 1024) {
                checksum12GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            }
        }
        
        // Compute 64GB checksum
        if size >= 64 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 64 * 1024 * 1024 * 1024) {
                checksum64GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            }
        }
        
        // Compute 128GB checksum
        if size >= 128 * 1024 * 1024 * 1024 {
            try fileHandle.seek(toOffset: 0)
            if let data = try fileHandle.read(upToCount: 128 * 1024 * 1024 * 1024) {
                checksum128GB = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            }
        }
        
        // Compute full file checksum
        try fileHandle.seek(toOffset: 0)
        if let data = try fileHandle.readToEnd() {
            checksumFull = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
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
            print("Failed to extract video metadata: \(error)")
        }
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
            print("Failed to extract audio metadata: \(error)")
        }
    }
    
    // MARK: - Duplicate Detection
    
    func isLikelyDuplicate(of other: FileInfo) -> Bool {
        // Use robust base name extraction
        let baseName = url.deletingPathExtension().lastPathComponent
        let otherBaseName = other.url.deletingPathExtension().lastPathComponent
        return baseName.lowercased() == otherBaseName.lowercased()
    }
    
    func isDefinitelyDuplicate(of other: FileInfo) -> Bool {
        guard size == other.size else { return false }
        
        // Compare checksums progressively
        if let checksum1KB = checksum1KB, let otherChecksum1KB = other.checksum1KB {
            if checksum1KB != otherChecksum1KB { return false }
        }
        
        if let checksum4GB = checksum4GB, let otherChecksum4GB = other.checksum4GB {
            if checksum4GB != otherChecksum4GB { return false }
        }
        
        if let checksum12GB = checksum12GB, let otherChecksum12GB = other.checksum12GB {
            if checksum12GB != otherChecksum12GB { return false }
        }
        
        if let checksum64GB = checksum64GB, let otherChecksum64GB = other.checksum64GB {
            if checksum64GB != otherChecksum64GB { return false }
        }
        
        if let checksum128GB = checksum128GB, let otherChecksum128GB = other.checksum128GB {
            if checksum128GB != otherChecksum128GB { return false }
        }
        
        if let checksumFull = checksumFull, let otherChecksumFull = other.checksumFull {
            return checksumFull == otherChecksumFull
        }
        
        return false
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
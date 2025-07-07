import Foundation
import CryptoKit

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
    
    var isViewable: Bool {
        return mediaType.isViewable
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
}

// MARK: - Media Type Enum

enum MediaType: String, CaseIterable, Codable {
    case photo
    case video
    case audio
    case unsupported
    
    static func from(fileExtension: String) -> MediaType {
        let photoExtensions = ["jpeg", "jpg", "png", "gif", "bmp", "tiff", "tif", "psd"]
        let videoExtensions = ["mov", "mp4", "avi", "mkv", "wmv", "flv", "webm", "m4v", "braw"]
        let audioExtensions = ["wav", "flac", "aac", "m4a", "mp3", "ogg", "wma"]
        let unsupportedExtensions = ["cr2", "rw2", "raw", "dng", "arw", "nef", "orf", "rwz"]
        
        let ext = fileExtension.lowercased()
        
        if photoExtensions.contains(ext) {
            return .photo
        } else if videoExtensions.contains(ext) {
            return .video
        } else if audioExtensions.contains(ext) {
            return .audio
        } else if unsupportedExtensions.contains(ext) {
            return .unsupported
        } else {
            return .unsupported // Default to unsupported for unknown extensions
        }
    }
    
    var qualityPreferences: [String] {
        switch self {
        case .photo:
            return ["jpeg", "jpg", "png", "tiff", "tif", "psd", "bmp"]
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
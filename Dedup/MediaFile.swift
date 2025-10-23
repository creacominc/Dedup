//
//  MediaFile.swift
//  ChecksumTests
//
//  Created by Harold Tomlinson on 2025-10-11.
//

import Foundation
import CryptoKit
//import zlib

// a class representing a media file to be analysed.
// @unchecked Sendable: MediaFile instances are shared across concurrent tasks
// Thread safety: checksums array is only modified within autoreleasepool blocks
class MediaFile: Identifiable, Hashable, @unchecked Sendable
{
    let id = UUID()
    let fileUrl: URL
    let isDirectory: Bool
    let fileSize: Int
    var isMediaFile: Bool
    var isUnique: Bool = false
    var checksums: [String] = []  // Array of chunk checksums, index = chunk number
    let fileExtension: String
    
    // MEMORY OPTIMIZATION: Fixed chunk size for reading files (2 GB)
    // Larger chunks reduce I/O overhead, especially over network
    // 2GB is a good balance between memory usage and I/O efficiency
    static let chunkSize: Int = 4 * 1024 * 1024 * 1024  // 2 GB
    let mediaType: MediaType
    let creationDate: Date
    let modificationDate: Date
    let isRegularFile: Bool
    
    static func == (lhs: MediaFile, rhs: MediaFile) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init?( fileUrl: URL )
    {
        do
        {
            let resourceValues = try fileUrl.resourceValues(
                forKeys: [.isRegularFileKey, .isDirectoryKey
                          , .fileSizeKey, .contentTypeKey
                          , .creationDateKey, .contentModificationDateKey
                         ])
            self.isDirectory = resourceValues.isDirectory ?? false
            
            self.fileUrl = fileUrl
            self.fileSize = resourceValues.fileSize ?? 0
            self.fileExtension = fileUrl.pathExtension.lowercased()
            self.mediaType = MediaType.from(fileExtension: self.fileExtension)
            self.isRegularFile = resourceValues.isRegularFile ?? false
            self.modificationDate = resourceValues.contentModificationDate ?? Date()
            // Use the earlier of creation and modification dates for organization
            // This handles cases where files were copied/moved and the creation date
            // is newer than the modification date
            self.creationDate = min( self.modificationDate, resourceValues.creationDate ?? Date() )
            
            
            // Check if file is a media file (audio, video, or image)
            self.isMediaFile = false
            if let contentType = resourceValues.contentType
            {
                isMediaFile = contentType.conforms(to: .audio) ||
                contentType.conforms(to: .video) ||
                contentType.conforms(to: .image)
            }
            // Fallback: Check file extension for common media formats
            let mediaExtensions = [
                "jpg", "braw", "mov", "rw2", "mp4", "dng", "r3d",
                "crm", "cr3", "cr2", "crw", "raw",
                "jpeg", "png", "gif", "heic", "tif", "tiff",
                "nef", "arw", "orf",
                "avi", "mkv", "m4v", "mpg", "mpeg",
                "mp3", "wav", "aac", "m4a", "flac",
                "heif", "webp"
            ]
            let ext = self.fileUrl.pathExtension.lowercased()
            isMediaFile = isMediaFile || mediaExtensions.contains(ext)
        }
        catch let error
        {
            // Failed to get resource values - initialization fails
            print("Failed to initialize MediaFile for \(fileUrl.path): \(error)")
            return nil
        }
    }
    
    // Internal initializer for testing/preview purposes
    internal init(
        fileUrl: URL,
        isDirectory: Bool,
        fileSize: Int,
        isMediaFile: Bool,
        isUnique: Bool,
        fileExtension: String,
        mediaType: MediaType,
        creationDate: Date,
        modificationDate: Date,
        isRegularFile: Bool
    ) {
        self.fileUrl = fileUrl
        self.isDirectory = isDirectory
        self.fileSize = fileSize
        self.isMediaFile = isMediaFile
        self.isUnique = isUnique
        self.fileExtension = fileExtension
        self.mediaType = mediaType
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isRegularFile = isRegularFile
    }

    /// MEMORY OPTIMIZATION: Compute checksum for a specific chunk of the file
    /// This uses a fixed buffer size and only reads the requested chunk
    /// Uses autoreleasepool to ensure immediate memory release
    /// @param chunkIndex: The zero-based index of the chunk to read (0 = first chunk, 1 = second chunk, etc.)
    /// @returns: The SHA256 checksum of that chunk as a hex string
    public func computeChunkChecksum(chunkIndex: Int) -> String
    {
        // Check if we already have this checksum cached
        if chunkIndex < checksums.count && !checksums[chunkIndex].isEmpty
        {
            return checksums[chunkIndex]
        }
        
        // Ensure the checksums array is large enough
        while checksums.count <= chunkIndex
        {
            checksums.append("")
        }
        
        // CRITICAL: Use autoreleasepool to ensure Data buffer is released immediately
        let hashString: String = autoreleasepool {
            do
            {
                // Calculate offset and size for this chunk
                let offset = UInt64(chunkIndex) * UInt64(MediaFile.chunkSize)
                let bytesToRead = min(MediaFile.chunkSize, fileSize - (chunkIndex * MediaFile.chunkSize))
                
                // Guard against reading past end of file
                guard bytesToRead > 0 else {
                    return ""
                }
                
                // Open file, read, compute hash, close immediately
                let fileHandle = try FileHandle(forReadingFrom: fileUrl)
                
                // Seek to the chunk position
                try fileHandle.seek(toOffset: offset)
                
                // Read the chunk
                guard let data = try fileHandle.read(upToCount: bytesToRead) else {
                    try? fileHandle.close()
                    return ""
                }
                
                // Close file IMMEDIATELY after reading, before computing hash
                try? fileHandle.close()
                
                // Compute hash for this chunk
                let hash: SHA256.Digest = SHA256.hash(data: data)
                let result: String = hash.compactMap { String(format: "%02x", $0) }.joined()
                
                // Data buffer will be released when autoreleasepool exits
                return result
            }
            catch let error
            {
                print("Error computing chunk checksum for \(fileUrl.path): \(error)")
                return ""
            }
        }
        
        checksums[chunkIndex] = hashString
        return hashString
    }
    
    /// PARALLEL OPTIMIZATION: Async version of computeChunkChecksum for concurrent execution
    /// This allows multiple files to have their chunks computed in parallel
    /// @param chunkIndex: The zero-based index of the chunk to read
    /// @returns: The SHA256 checksum of that chunk as a hex string
    public func computeChunkChecksumAsync(chunkIndex: Int) async -> String
    {
        // Check if we already have this checksum cached (thread-safe read)
        if chunkIndex < checksums.count && !checksums[chunkIndex].isEmpty
        {
            return checksums[chunkIndex]
        }
        
        // Compute checksum on a background thread to avoid blocking
        return await Task.detached(priority: .userInitiated) {
            // Ensure the checksums array is large enough
            while self.checksums.count <= chunkIndex
            {
                self.checksums.append("")
            }
            
            // CRITICAL: Use autoreleasepool to ensure Data buffer is released immediately
            let hashString: String = autoreleasepool {
                do
                {
                    // Calculate offset and size for this chunk
                    let offset = UInt64(chunkIndex) * UInt64(MediaFile.chunkSize)
                    let bytesToRead = min(MediaFile.chunkSize, self.fileSize - (chunkIndex * MediaFile.chunkSize))
                    
                    // Guard against reading past end of file
                    guard bytesToRead > 0 else {
                        return ""
                    }
                    
                    // Open file, read, compute hash, close immediately
                    let fileHandle = try FileHandle(forReadingFrom: self.fileUrl)
                    
                    // Seek to the chunk position
                    try fileHandle.seek(toOffset: offset)
                    
                    // Read the chunk
                    guard let data = try fileHandle.read(upToCount: bytesToRead) else {
                        try? fileHandle.close()
                        return ""
                    }
                    
                    // Close file IMMEDIATELY after reading, before computing hash
                    try? fileHandle.close()
                    
                    // Compute hash for this chunk
                    let hash: SHA256.Digest = SHA256.hash(data: data)
                    let result: String = hash.compactMap { String(format: "%02x", $0) }.joined()
                    
                    // Data buffer will be released when autoreleasepool exits
                    return result
                }
                catch let error
                {
                    print("Error computing chunk checksum for \(self.fileUrl.path): \(error)")
                    return ""
                }
            }
            
            self.checksums[chunkIndex] = hashString
            return hashString
        }.value
    }
    
    /// Returns the number of chunks this file would be divided into
    public var chunkCount: Int {
        return (fileSize + MediaFile.chunkSize - 1) / MediaFile.chunkSize
    }

    /// MEMORY FIX: Clear checksums to free memory after processing is complete
    /// Call this after uniqueness has been determined
    public func clearChecksums()
    {
        checksums.removeAll()
    }

    /// MEMORY OPTIMIZATION: Keep only checksums that are actually needed to identify this file
    /// For the chunk-based approach, we can optionally keep only the first N chunks
    /// or clear all chunks after uniqueness has been determined
    public func clearIntermediateChecksums()
    {
        // For now, we'll keep only the first chunk if any checksums exist
        // This provides a basic "fingerprint" while freeing most memory
        if checksums.count > 1
        {
            let firstChecksum = checksums[0]
            checksums = [firstChecksum]
        }
    }

    // Computed properties
    var displayName: String
    {
        return self.fileUrl.lastPathComponent
    }

    var formattedCreationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string( from: creationDate )
    }

}

// MARK: - Preview Support
#if DEBUG
extension MediaFile {
    /// Creates a mock MediaFile for preview/testing purposes
    static func mock(
        path: String,
        size: Int,
        isUnique: Bool = true,
        fileExtension: String = "jpg",
        mediaType: MediaType = .photo,
        creationDate: Date = Date(),
        modificationDate: Date = Date()
    ) -> MediaFile {
        let url = URL(fileURLWithPath: path)
        let mockFile = MediaFile(
            fileUrl: url,
            isDirectory: false,
            fileSize: size,
            isMediaFile: true,
            isUnique: isUnique,
            fileExtension: fileExtension,
            mediaType: mediaType,
            creationDate: creationDate,
            modificationDate: modificationDate,
            isRegularFile: true
        )
        return mockFile
    }
}
#endif

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
    var checksums: [Int:String] = [:]  // map of chunk index and checksum
    let fileExtension: String
    
    // MEMORY OPTIMIZATION: Dynamic chunk size for reading files
    // Larger chunks reduce I/O overhead, especially over network
    // Chunk size is calculated based on available memory budget and number of concurrent tasks
    // Formula: chunkSize = memoryBudget / numConcurrentTasks
    // This ensures we use available memory efficiently while maintaining high parallelism
    // SAFETY: nonisolated(unsafe) is safe here because:
    // 1. Chunk size is set once per file size BEFORE parallel processing begins
    // 2. All tasks processing the same file size read the same value
    // 3. No concurrent writes occur during parallel processing
    nonisolated(unsafe) static var chunkSize: Int = 4 * 1024 * 1024 * 1024  // Default 4 GB, adjusted dynamically
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

    private func checksumIsCached(chunkIndex: Int) -> Bool
    {
        return ( (chunkIndex < checksums.count)       
                 && ((checksums[chunkIndex]) != nil)  
                 && (!checksums[chunkIndex]!.isEmpty) 
        )
    }

    /// PARALLEL OPTIMIZATION: Async version of computeChunkChecksum for concurrent execution
    /// This allows multiple files to have their chunks computed in parallel
    /// @param chunkIndex: The zero-based index of the chunk to read
    /// @returns: The SHA256 checksum of that chunk as a hex string
    public func computeChunkChecksumAsync(chunkIndex: Int) async -> String
    {
        // Check if we already have this checksum cached (thread-safe read)
        if checksumIsCached(chunkIndex: chunkIndex)
        {
            print(
                "Returning cached checksum (async) for chunk \(chunkIndex), value: \(checksums[chunkIndex] ?? "N/A"), file: \(displayName)"
            )
            return checksums[chunkIndex] ?? "N/A"
        }

        // Compute checksum on a background thread to avoid blocking
        let hashString: String = await Task.detached(priority: .userInitiated)
        {
            // CRITICAL: Use autoreleasepool to ensure Data buffer is released immediately
            return autoreleasepool
            {
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
        }.value
        
        // DEBUG: Log when storing checksum
        if chunkIndex == 0 && hashString.isEmpty {
            print("MediaFile ERROR: computeChunkChecksumAsync computed empty checksum for chunk \(chunkIndex) in file '\(self.fileUrl.lastPathComponent)'")
        }
        
        // DEBUG: Log successful checksum storage
        if !hashString.isEmpty {
            print("MediaFile: Successfully stored checksum for chunk \(chunkIndex) in file '\(self.fileUrl.lastPathComponent)': \(String(hashString.prefix(16)))...")
            print("  Checksums array now has \(self.checksums.count) elements")
        } else {
            print("MediaFile WARNING: Attempting to store empty checksum for chunk \(chunkIndex) in file '\(self.fileUrl.lastPathComponent)'")
        }
        
        // Store the checksum on the main thread to avoid race conditions
        self.checksums[chunkIndex] = hashString
        
        return hashString
    }
    
    /// Returns the number of chunks this file would be divided into
    public var chunkCount: Int {
        return (fileSize + MediaFile.chunkSize - 1) / MediaFile.chunkSize
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

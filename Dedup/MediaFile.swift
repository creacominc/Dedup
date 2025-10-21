//
//  MediaFile.swift
//  ChecksumTests
//
//  Created by Harold Tomlinson on 2025-10-11.
//

import Foundation
import CryptoKit

// a class representing a media file to be analysed.
class MediaFile: Identifiable, Hashable
{
    let id = UUID()
    let fileUrl: URL
    let isDirectory: Bool
    let fileSize: Int
    var isMediaFile: Bool
    var isUnique: Bool = false
    var checksums: [Int: String] = [:]
    let fileExtension: String
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
    
    public func computeChecksum( size: Int ) -> String
    {
        // Check if we already have this checksum cached
        if let cached = checksums[size] {
            return cached
        }
        
        do
        {
            let fileHandle = try FileHandle( forReadingFrom: fileUrl )
            defer { try? fileHandle.close() }
            if let data = try fileHandle.read(upToCount: size)
            {
                // MEMORY FIX: Compute hash more efficiently
                let hash = SHA256.hash(data: data)
                let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                checksums[size] = hashString
                // Data object is released here automatically when it goes out of scope
            }
        }
        catch(let e)
        {
            print("Error: \(e)")
        }
        return checksums[size, default: ""]
    }
    
    /// MEMORY FIX: Clear checksums to free memory after processing is complete
    /// Call this after uniqueness has been determined
    public func clearChecksums() {
        checksums.removeAll()
    }
    
    /// MEMORY FIX: Keep only the largest checksum (final result) and remove intermediate checksums
    /// This significantly reduces memory usage while preserving the identification capability
    public func clearIntermediateChecksums() {
        guard let maxKey = checksums.keys.max() else { return }
        let finalChecksum = checksums[maxKey]
        checksums.removeAll()
        if let final = finalChecksum {
            checksums[maxKey] = final
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

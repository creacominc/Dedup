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

    public func computeChecksum( size: Int ) -> String
    {
        do
        {
            let fileHandle = try FileHandle( forReadingFrom: fileUrl )
            defer { try? fileHandle.close() }
            if let data = try fileHandle.read(upToCount: size)
            {
                checksums[size] = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
            }
        }
        catch(let e)
        {
            print("Error: \(e)")
        }
        return checksums[size, default: ""]
    }

    // Computed properties
    var displayName: String
    {
        return self.fileUrl.lastPathComponent
    }

}

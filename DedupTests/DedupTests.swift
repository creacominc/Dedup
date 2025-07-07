//
//  DedupTests.swift
//  DedupTests
//
//  Created by Harold Tomlinson on 2025-07-05.
//

import XCTest
import Foundation
@testable import Dedup

final class DedupTests: XCTestCase {
    
    // MARK: - FileInfo Tests
    
    func testFileInfoInitialization() throws {
        // Create a temporary file for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_file.txt")
        let testData = "Test content".data(using: .utf8)!
        try testData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let fileInfo = try FileInfo(url: tempURL)
        
        XCTAssertEqual(fileInfo.name, "test_file.txt")
        XCTAssertEqual(fileInfo.fileExtension, "txt")
        XCTAssertEqual(fileInfo.size, Int64(testData.count))
        XCTAssertNotNil(fileInfo.creationDate)
        XCTAssertNotNil(fileInfo.modificationDate)
    }
    
    func testFileInfoWithInvalidURL() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.txt")
        
        // The test should expect that creating FileInfo with an invalid URL throws an error
        // The actual error type depends on the system, so we'll just check that it throws
        XCTAssertThrowsError(try FileInfo(url: invalidURL))
    }
    
    // MARK: - MediaType Tests
    
    func testMediaTypeDetection() {
        // Photo formats
        XCTAssertEqual(MediaType.from(fileExtension: "cr2"), .photo)
        XCTAssertEqual(MediaType.from(fileExtension: "rw2"), .photo)
        XCTAssertEqual(MediaType.from(fileExtension: "jpg"), .photo)
        XCTAssertEqual(MediaType.from(fileExtension: "png"), .photo)
        XCTAssertEqual(MediaType.from(fileExtension: "tiff"), .photo)
        
        // Video formats
        XCTAssertEqual(MediaType.from(fileExtension: "braw"), .video)
        XCTAssertEqual(MediaType.from(fileExtension: "mov"), .video)
        XCTAssertEqual(MediaType.from(fileExtension: "mp4"), .video)
        XCTAssertEqual(MediaType.from(fileExtension: "avi"), .video)
        
        // Audio formats
        XCTAssertEqual(MediaType.from(fileExtension: "wav"), .audio)
        XCTAssertEqual(MediaType.from(fileExtension: "mp3"), .audio)
        XCTAssertEqual(MediaType.from(fileExtension: "flac"), .audio)
    }
    
    func testMediaTypeQualityPreferences() {
        let photoPreferences = MediaType.photo.qualityPreferences
        XCTAssertTrue(photoPreferences.contains("cr2"))
        XCTAssertTrue(photoPreferences.contains("rw2"))
        XCTAssertTrue(photoPreferences.contains("jpg"))
        
        let videoPreferences = MediaType.video.qualityPreferences
        XCTAssertTrue(videoPreferences.contains("braw"))
        XCTAssertTrue(videoPreferences.contains("mov"))
        XCTAssertTrue(videoPreferences.contains("mp4"))
        
        let audioPreferences = MediaType.audio.qualityPreferences
        XCTAssertTrue(audioPreferences.contains("wav"))
        XCTAssertTrue(audioPreferences.contains("flac"))
        XCTAssertTrue(audioPreferences.contains("mp3"))
    }
    
    func testMediaTypeQualityScores() {
        XCTAssertEqual(MediaType.photo.qualityScore, 3)
        XCTAssertEqual(MediaType.video.qualityScore, 2)
        XCTAssertEqual(MediaType.audio.qualityScore, 1)
    }
    
    // MARK: - Duplicate Detection Tests
    
    func testLikelyDuplicateDetection() {
        // Create test files with the same base name but different extensions
        let file1 = createTestFileInfo(name: "P102497.JPG", size: 1024)
        let file2 = createTestFileInfo(name: "P102497.RW2", size: 2048)
        let file3 = createTestFileInfo(name: "P102498.JPG", size: 1024)
        
        // Files with same base name but different extensions should be likely duplicates
        XCTAssertTrue(file1.isLikelyDuplicate(of: file2))
        XCTAssertFalse(file1.isLikelyDuplicate(of: file3))
    }
    
    func testDefinitelyDuplicateDetection() {
        let file1 = createTestFileInfo(name: "test1.jpg", size: 1024)
        let file2 = createTestFileInfo(name: "test2.jpg", size: 1024)
        let file3 = createTestFileInfo(name: "test3.jpg", size: 2048)
        
        // Files with different sizes are not duplicates
        XCTAssertFalse(file1.isDefinitelyDuplicate(of: file3))
        
        // Files with same size but no checksums are not considered duplicates
        XCTAssertFalse(file1.isDefinitelyDuplicate(of: file2))
    }
    
    func testQualityComparison() {
        let rawFile = createTestFileInfo(name: "test.CR2", size: 1024)
        let jpgFile = createTestFileInfo(name: "test.JPG", size: 1024)
        
        // CR2 should be considered higher quality than JPG
        // CR2 appears earlier in the quality preferences list than JPG
        XCTAssertTrue(rawFile.isHigherQuality(than: jpgFile))
        XCTAssertFalse(jpgFile.isHigherQuality(than: rawFile))
    }
    
    // MARK: - File Processing Tests
    
    @MainActor
    func testIsMediaFile() {
        let processor = FileProcessor()
        
        // Test media files
        let mediaURLs = [
            URL(fileURLWithPath: "/test/image.jpg"),
            URL(fileURLWithPath: "/test/video.mov"),
            URL(fileURLWithPath: "/test/audio.wav"),
            URL(fileURLWithPath: "/test/raw.CR2"),
            URL(fileURLWithPath: "/test/video.BRAW")
        ]
        
        for url in mediaURLs {
            XCTAssertTrue(processor.isMediaFile(url))
        }
        
        // Test non-media files
        let nonMediaURLs = [
            URL(fileURLWithPath: "/test/document.pdf"),
            URL(fileURLWithPath: "/test/text.txt"),
            URL(fileURLWithPath: "/test/archive.zip")
        ]
        
        for url in nonMediaURLs {
            XCTAssertFalse(processor.isMediaFile(url))
        }
    }
    
    func testBRAWFileSupport() {
        // Test BRAW file detection
        let brawURL = URL(fileURLWithPath: "/test/video.braw")
        let fileInfo = try! FileInfo(url: brawURL)
        
        XCTAssertEqual(fileInfo.mediaType, .video)
        XCTAssertTrue(fileInfo.isBRAWFile)
        XCTAssertTrue(fileInfo.isViewable)
        
        // Test BRAW support utilities
        let brawSupport = BRAWSupport.shared
        
        // These should be false in test environment, but we can test the structure
        XCTAssertFalse(brawSupport.hasBlackmagicRAWPlayer)
        XCTAssertFalse(brawSupport.hasDaVinciResolve)
        XCTAssertFalse(brawSupport.hasFFmpeg)
        XCTAssertFalse(brawSupport.hasBRAWPlaybackSupport)
        XCTAssertNil(brawSupport.bestBRAWPlayer)
    }
    
    func testRAWFileSupport() {
        // Test RAW file detection
        let rawURLs = [
            URL(fileURLWithPath: "/test/image.rw2"),
            URL(fileURLWithPath: "/test/image.cr2"),
            URL(fileURLWithPath: "/test/image.dng"),
            URL(fileURLWithPath: "/test/image.arw"),
            URL(fileURLWithPath: "/test/image.nef"),
            URL(fileURLWithPath: "/test/image.orf"),
            URL(fileURLWithPath: "/test/image.rwz"),
            URL(fileURLWithPath: "/test/image.raw")
        ]
        
        for url in rawURLs {
            let fileInfo = try! FileInfo(url: url)
            XCTAssertEqual(fileInfo.mediaType, .photo)
            XCTAssertTrue(fileInfo.isRAWFile)
            XCTAssertTrue(fileInfo.isViewable)
        }
        
        // Test RAW support utilities
        let rawSupport = RAWSupport.shared
        
        // These should be false in test environment, but we can test the structure
        XCTAssertTrue(rawSupport.hasPreview) // Preview is always available
        XCTAssertFalse(rawSupport.hasPhotos)
        XCTAssertFalse(rawSupport.hasLightroom)
        XCTAssertFalse(rawSupport.hasCaptureOne)
        XCTAssertFalse(rawSupport.hasFFmpeg)
        XCTAssertTrue(rawSupport.hasRAWViewingSupport) // Should be true because of Preview
        XCTAssertEqual(rawSupport.bestRAWViewer, "Preview")
    }
    
    // MARK: - Helper Methods
    
    private func createTestFileInfo(name: String, size: Int64) -> FileInfo {
        // Create a temporary file for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let testData = Data(repeating: 0, count: Int(size))
        try? testData.write(to: tempURL)
        
        do {
            let fileInfo = try FileInfo(url: tempURL)
            // Clean up the temporary file
            try? FileManager.default.removeItem(at: tempURL)
            return fileInfo
        } catch {
            // If we can't create the file, create a simple test file
            let simpleURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_\(name)")
            let simpleData = "test".data(using: .utf8)!
            try? simpleData.write(to: simpleURL)
            
            do {
                let fileInfo = try FileInfo(url: simpleURL)
                try? FileManager.default.removeItem(at: simpleURL)
                return fileInfo
            } catch {
                fatalError("Could not create test file: \(error)")
            }
        }
    }
} 
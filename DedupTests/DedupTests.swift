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
        
        XCTAssertThrowsError(try FileInfo(url: invalidURL)) { error in
            XCTAssertTrue(error is FileError)
        }
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
        let file1 = createTestFileInfo(name: "P102497.JPG", size: 1024)
        let file2 = createTestFileInfo(name: "P102497.RW2", size: 2048)
        let file3 = createTestFileInfo(name: "P102498.JPG", size: 1024)
        
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
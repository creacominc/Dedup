import CryptoKit
import Foundation
import Testing
@testable import Dedup

struct DedupTests {
    @Test func `Progressive prefixes reject files before a full read`() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = directory.appending(path: "A.mov")
        let secondURL = directory.appending(path: "B.mov")
        try Data([0x01] + Array(repeating: 0xAA, count: 4_095)).write(to: firstURL)
        try Data([0x02] + Array(repeating: 0xAA, count: 4_095)).write(to: secondURL)
        let first = try record(for: firstURL)
        let second = try record(for: secondURL)
        let hasher = ProgressiveHasher()

        let firstPrefix = try await hasher.prefixDigest(for: first, byteLimit: 256)
        let secondPrefix = try await hasher.prefixDigest(for: second, byteLimit: 256)

        #expect(first.byteCount == second.byteCount)
        #expect(firstPrefix.digest != secondPrefix.digest)
        #expect(firstPrefix.byteCount == 256)
    }

    @Test func `Different names with identical content are exact duplicates`() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "Source", directoryHint: .isDirectory)
        let target = root.appending(path: "Target", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        let bytes = Data((0..<8_192).map { UInt8($0 % 251) })
        try bytes.write(to: source.appending(path: "A.MOV"))
        try bytes.write(to: target.appending(path: "B.MOV"))

        let report = try await DeduplicationEngine().analyze(source: source, target: target) { _ in }

        let group = try #require(report.duplicateGroups.first)
        #expect(group.files.count == 2)
        #expect(Set(group.files.map(\.displayName)) == ["A.MOV", "B.MOV"])
        #expect(report.uniqueSourceFiles.isEmpty)
    }

    @Test func `Scanner skips symbolic links and their descendants`() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: outside) }
        try Data([1, 2, 3]).write(to: outside.appending(path: "outside.mov"))
        try FileManager.default.createSymbolicLink(at: root.appending(path: "linked"), withDestinationURL: outside)
        try Data([4, 5, 6]).write(to: root.appending(path: "inside.mov"))

        let result = try await MediaScanner().scan(root: root)

        #expect(result.records.map(\.displayName) == ["inside.mov"])
    }

    @Test func `Dry run reports actions without changing files`() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "source.mov")
        let destination = root.appending(path: "Library/video.mov")
        try Data([9, 8, 7]).write(to: source)
        let operation = PlannedOperation(
            kind: .moveToLibrary,
            source: source,
            destination: destination,
            byteCount: 3,
            expectedDigest: nil,
            explanation: "test"
        )

        let results = await OperationExecutor().execute(
            plan: OperationPlan(operations: [operation], createdAt: .now),
            dryRun: true
        )

        #expect(FileManager.default.fileExists(atPath: source.path()))
        #expect(!FileManager.default.fileExists(atPath: destination.path()))
        #expect(results.count == 1)
        #expect(results[0].performed == false)
    }

    @Test func `Verified transfer copies content before removing source`() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "source.mov")
        let destination = root.appending(path: "Library/video.mov")
        let bytes = Data((0..<32_768).map { UInt8($0 % 239) })
        try bytes.write(to: source)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let operation = PlannedOperation(
            kind: .moveToLibrary,
            source: source,
            destination: destination,
            byteCount: Int64(bytes.count),
            expectedDigest: digest,
            explanation: "test"
        )

        let results = await OperationExecutor().execute(
            plan: OperationPlan(operations: [operation], createdAt: .now),
            dryRun: false
        )

        #expect(!FileManager.default.fileExists(atPath: source.path()))
        #expect(try Data(contentsOf: destination) == bytes)
        #expect(results.first?.performed == true)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "DedupTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func record(for url: URL) throws -> MediaRecord {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
        return MediaRecord(
            id: url.path(),
            url: url,
            byteCount: Int64(try #require(values.fileSize)),
            creationDate: values.creationDate ?? .distantPast,
            modificationDate: values.contentModificationDate ?? .distantPast,
            kind: .video,
            fileResourceIdentifier: nil
        )
    }
}

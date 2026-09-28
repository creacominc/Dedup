import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Dedup

struct MediaClassificationTests {
    @Test(
        "Extensions map to media kinds",
        arguments: [
            ("clip.MOV", MediaKind.video),
            ("clip.braw", MediaKind.video),
            ("still.RW2", MediaKind.photo),
            ("still.jpg", MediaKind.photo),
            ("sound.WAV", MediaKind.audio),
            ("sound.flac", MediaKind.audio)
        ]
    )
    func extensionClassification(filename: String, expected: MediaKind) {
        #expect(MediaKind.classify(url: URL(filePath: filename), contentType: nil) == expected)
    }

    @Test func `Uniform type takes precedence over extension`() {
        #expect(MediaKind.classify(url: URL(filePath: "misnamed.bin"), contentType: .movie) == .video)
        #expect(MediaKind.classify(url: URL(filePath: "misnamed.bin"), contentType: .image) == .photo)
        #expect(MediaKind.classify(url: URL(filePath: "misnamed.bin"), contentType: .audio) == .audio)
    }

    @Test func `Unknown files are ignored`() {
        #expect(MediaKind.classify(url: URL(filePath: "notes.txt"), contentType: .plainText) == nil)
    }
}

@Suite(.serialized)
struct LegacyModelCoverageTests {
    @Test(
        "Legacy media type classification remains consistent",
        arguments: [
            ("jpg", MediaType.photo),
            ("rw2", MediaType.photo),
            ("mov", MediaType.video),
            ("braw", MediaType.video),
            ("wav", MediaType.audio),
            ("txt", MediaType.unsupported)
        ]
    )
    func mediaTypeClassification(fileExtension: String, expected: MediaType) {
        let type = MediaType.from(fileExtension: fileExtension)
        #expect(type == expected)
        #expect(type.displayName.isEmpty == false)
        #expect(type.qualityScore >= 0)
        #expect(type.isViewable == (type != .unsupported))
    }

    @Test func `Legacy media file exposes metadata and ordered chunk hashes`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let url = fixture.source.appending(path: "legacy.mov")
            try Data([1, 2, 3, 4]).write(to: url)
            let file = try #require(MediaFile(fileUrl: url))
            let originalChunkSize = MediaFile.chunkSize
            defer { MediaFile.chunkSize = originalChunkSize }
            MediaFile.chunkSize = 2

            let first = await file.computeChunkChecksumAsync(chunkIndex: 0)
            let second = await file.computeChunkChecksumAsync(chunkIndex: 1)

            #expect(file.displayName == "legacy.mov")
            #expect(file.fileSize == 4)
            #expect(file.mediaType == .video)
            #expect(file.chunkCount == 2)
            #expect(first.isEmpty == false)
            #expect(second.isEmpty == false)
            #expect(first != second)
            #expect(file.formattedCreationDate.isEmpty == false)
        }
    }

    @Test func `Legacy file set supports append merge iteration and removal`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let first = try fixture.makeLegacyMediaFile(name: "first.mov", bytes: [1, 2, 3])
            let second = try fixture.makeLegacyMediaFile(name: "second.mov", bytes: [4, 5, 6])
            let third = try fixture.makeLegacyMediaFile(name: "third.mov", bytes: [7])
            let left = FileSetBySize()
            let right = FileSetBySize()
            left.append(first)
            left.append(contentsOf: [third])
            right.append(second)

            let limited = left.merge(with: right, sizeLimit: true)
            var iterated = 0
            limited.forEachFile { _ in iterated += 1 }

            #expect(left.totalFileCount == 2)
            #expect(left.contains(size: 3))
            #expect(left.count(for: 3) == 1)
            #expect(left.sortedSizes == [1, 3])
            #expect(limited.totalFileCount == 3)
            #expect(iterated == 3)
            #expect(limited.sizesWithMultipleFiles == [3])
            #expect(limited.formatBytes(1_024).isEmpty == false)
            limited.remove(mediaFile: second)
            #expect(limited.totalFileCount == 2)
            limited.removeAll()
            #expect(limited.totalFileCount == 0)
        }
    }
}

struct ScannerCoverageTests {
    @Test func `Scanner ignores hidden unsupported and duplicate hard-linked files`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let visible = fixture.source.appending(path: "visible.mov")
            try Data([1, 2, 3]).write(to: visible)
            try Data([4]).write(to: fixture.source.appending(path: ".hidden.mov"))
            try Data([5]).write(to: fixture.source.appending(path: "notes.txt"))
            try FileManager.default.linkItem(at: visible, to: fixture.source.appending(path: "hard-link.mov"))

            let result = try await MediaScanner().scan(root: fixture.source)

            #expect(result.records.count == 1)
            #expect(result.records[0].byteCount == 3)
            #expect(result.records[0].kind == .video)
        }
    }

    @Test func `Scanner rejects a file as its root`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let file = fixture.root.appending(path: "not-a-folder.mov")
            try Data([1]).write(to: file)
            await #expect(throws: MediaScannerError.self) {
                _ = try await MediaScanner().scan(root: file)
            }
        }
    }
}

struct HashingCoverageTests {
    @Test func `Prefix limit is clamped to file size`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let url = fixture.source.appending(path: "small.mov")
            try Data([1, 2, 3, 4]).write(to: url)
            let record = try TemporaryFixture.record(for: url)

            let checkpoint = try await ProgressiveHasher().prefixDigest(for: record, byteLimit: 1_000)

            #expect(checkpoint.byteCount == 4)
            #expect(checkpoint.digest.count == 64)
        }
    }

    @Test func `Changed metadata invalidates a record`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let url = fixture.source.appending(path: "changing.mov")
            try Data([1, 2, 3]).write(to: url)
            let staleRecord = try TemporaryFixture.record(for: url)
            try Data([1, 2, 3, 4]).write(to: url)

            await #expect(throws: HashingError.self) {
                _ = try await ProgressiveHasher().fullDigest(for: staleRecord)
            }
        }
    }

    @Test func `Hash cache returns matching metadata and rejects stale metadata`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let cacheURL = fixture.root.appending(path: "cache.json")
            let mediaURL = fixture.source.appending(path: "cached.mov")
            try Data([8, 7, 6]).write(to: mediaURL)
            let record = try TemporaryFixture.record(for: mediaURL)
            let cache = HashCache(storeURL: cacheURL)
            let checkpoint = HashCheckpoint(byteCount: 3, digest: "abc")

            await cache.store(checkpoint, for: record)

            #expect(await cache.digest(for: record, byteCount: 3) == "abc")
            let stale = MediaRecord(
                id: record.id,
                url: record.url,
                byteCount: record.byteCount + 1,
                creationDate: record.creationDate,
                modificationDate: record.modificationDate,
                kind: record.kind,
                fileResourceIdentifier: record.fileResourceIdentifier
            )
            #expect(await cache.digest(for: stale, byteCount: 3) == nil)
            #expect(FileManager.default.fileExists(atPath: cacheURL.path()))
        }
    }
}

struct EngineCoverageTests {
    @Test func `Engine reports unique files and progress`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            try Data([1, 2, 3]).write(to: fixture.source.appending(path: "one.mov"))
            try Data([9, 8, 7, 6]).write(to: fixture.source.appending(path: "two.mov"))
            let recorder = ProgressRecorder()

            let report = try await DeduplicationEngine().analyze(source: fixture.source, target: fixture.target) { progress in
                await recorder.append(progress)
            }

            #expect(report.uniqueSourceFiles.count == 2)
            #expect(report.duplicateGroups.isEmpty)
            #expect(await recorder.values.isEmpty == false)
        }
    }

    @Test func `Same-size different content is unique after its first differing prefix`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            try Data([1] + Array(repeating: 0, count: 511)).write(to: fixture.source.appending(path: "one.mov"))
            try Data([2] + Array(repeating: 0, count: 511)).write(to: fixture.target.appending(path: "two.mov"))

            let report = try await DeduplicationEngine().analyze(source: fixture.source, target: fixture.target) { _ in }

            #expect(report.duplicateGroups.isEmpty)
            #expect(report.uniqueSourceFiles.count == 1)
        }
    }
}

struct PlanningCoverageTests {
    @Test func `Destination layout creates all media roots`() throws {
        let fixture = try TemporaryFixture()
        defer { fixture.remove() }
        let destination = fixture.root.appending(path: "NewResults", directoryHint: .isDirectory)

        try DestinationLayout.ensureDirectories(at: destination)

        for kind in MediaKind.allCases {
            var isDirectory: ObjCBool = false
            #expect(FileManager.default.fileExists(atPath: destination.appending(path: kind.rawValue).path(), isDirectory: &isDirectory))
            #expect(isDirectory.boolValue)
        }
    }

    @Test func `Unique source receives dated media destination`() throws {
        let fixture = try TemporaryFixture()
        defer { fixture.remove() }
        let record = try fixture.makeRecord(name: "camera.mov", bytes: [1, 2, 3])
        let report = AnalysisReport(sourceFiles: [record], targetFiles: [], uniqueSourceFiles: [record], duplicateGroups: [], issues: [])

        let plan = OperationPlanner().makePlan(report: report, sourceRoot: fixture.source, targetRoot: fixture.target)

        let operation = try #require(plan.operations.first)
        #expect(operation.kind == .moveToLibrary)
        #expect(operation.destination?.path().contains("/Videos/") == true)
        #expect(operation.destination?.lastPathComponent == "camera.mov")
    }

    @Test func `Existing different destination becomes a conflict`() throws {
        let fixture = try TemporaryFixture()
        defer { fixture.remove() }
        let record = try fixture.makeRecord(name: "camera.mov", bytes: [1, 2, 3])
        let preliminary = OperationPlanner().makePlan(
            report: AnalysisReport(sourceFiles: [record], targetFiles: [], uniqueSourceFiles: [record], duplicateGroups: [], issues: []),
            sourceRoot: fixture.source,
            targetRoot: fixture.target
        )
        let destination = try #require(preliminary.operations.first?.destination)
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([9]).write(to: destination)

        let plan = OperationPlanner().makePlan(
            report: AnalysisReport(sourceFiles: [record], targetFiles: [], uniqueSourceFiles: [record], duplicateGroups: [], issues: []),
            sourceRoot: fixture.source,
            targetRoot: fixture.target
        )

        #expect(plan.operations.first?.kind == .conflict)
    }

    @Test func `Target duplicate produces a quarantine action`() throws {
        let fixture = try TemporaryFixture()
        defer { fixture.remove() }
        let source = try fixture.makeRecord(name: "source.mov", bytes: [1, 2, 3])
        let target = try fixture.makeRecord(name: "target.mov", bytes: [1, 2, 3], in: fixture.target)
        let group = DuplicateGroupResult(digest: "same", files: [source, target])
        let report = AnalysisReport(sourceFiles: [source], targetFiles: [target], uniqueSourceFiles: [], duplicateGroups: [group], issues: [])

        let plan = OperationPlanner().makePlan(report: report, sourceRoot: fixture.source, targetRoot: fixture.target)

        #expect(plan.operations.first?.kind == .quarantineDuplicate)
        #expect(plan.operations.first?.destination?.path(percentEncoded: false).contains(".Dedup Quarantine") == true)
    }
}

struct ExecutorCoverageTests {
    @Test func `Executor reports an atomic move on the same filesystem`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let source = fixture.source.appending(path: "progress.mov")
            let destination = fixture.target.appending(path: "progress.mov")
            try Data([1, 2, 3, 4]).write(to: source)
            let operation = PlannedOperation(kind: .moveToLibrary, source: source, destination: destination, byteCount: 4, expectedDigest: nil, explanation: "test")
            let recorder = OperationProgressRecorder()

            _ = await OperationExecutor().execute(
                plan: OperationPlan(operations: [operation], createdAt: .now),
                dryRun: false
            ) { update in
                await recorder.append(update)
            }

            let updates = await recorder.values
            #expect(updates.contains { $0.message.contains("Moving progress.mov on the same filesystem") })
            #expect(updates.last?.completed == 1)
            #expect(updates.last?.result?.performed == true)
            #expect(updates.last?.result?.message.contains("Moved atomically") == true)
            #expect(!FileManager.default.fileExists(atPath: source.path()))
            #expect(try Data(contentsOf: destination) == Data([1, 2, 3, 4]))
        }
    }

    @Test func `Digest mismatch leaves source intact and removes staging file`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let source = fixture.source.appending(path: "source.mov")
            let destination = fixture.target.appending(path: "destination.mov")
            try Data([1, 2, 3]).write(to: source)
            let operation = PlannedOperation(kind: .moveToLibrary, source: source, destination: destination, byteCount: 3, expectedDigest: "wrong", explanation: "test")

            let results = await OperationExecutor(forceVerifiedCopy: true).execute(plan: OperationPlan(operations: [operation], createdAt: .now), dryRun: false)

            #expect(FileManager.default.fileExists(atPath: source.path()))
            #expect(!FileManager.default.fileExists(atPath: destination.path()))
            #expect(results.first?.performed == false)
            #expect(try FileManager.default.contentsOfDirectory(at: fixture.target, includingPropertiesForKeys: nil).isEmpty)
        }
    }

    @Test func `Verified copy reports each phase and removes source only after verification`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let source = fixture.source.appending(path: "cross-volume.mov")
            let destination = fixture.target.appending(path: "Nested/cross-volume.mov")
            let bytes = Data((0..<2_097_152).map { UInt8($0 % 251) })
            try bytes.write(to: source)
            let operation = PlannedOperation(
                kind: .moveToLibrary,
                source: source,
                destination: destination,
                byteCount: Int64(bytes.count),
                expectedDigest: nil,
                explanation: "test"
            )
            let recorder = OperationProgressRecorder()

            let results = await OperationExecutor(forceVerifiedCopy: true).execute(
                plan: OperationPlan(operations: [operation], createdAt: .now),
                dryRun: false
            ) { update in
                await recorder.append(update)
            }

            let messages = await recorder.values.map(\.message)
            #expect(messages.contains { $0.contains("Different filesystems; copying") })
            #expect(messages.contains { $0.contains("Copying cross-volume.mov") })
            #expect(messages.contains { $0.contains("Hashing source") })
            #expect(messages.contains { $0.contains("Hashing staged copy") })
            #expect(messages.contains { $0.contains("Committing") })
            #expect(messages.contains { $0.contains("Removing verified source") })
            #expect(results.first?.performed == true)
            #expect(results.first?.message == "Copied, verified, and committed")
            #expect(!FileManager.default.fileExists(atPath: source.path()))
            #expect(try Data(contentsOf: destination) == bytes)
        }
    }

    @Test func `Skip and conflict operations never change files`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let skippedSource = fixture.source.appending(path: "skip.mov")
            let conflictSource = fixture.source.appending(path: "conflict.mov")
            try Data([1]).write(to: skippedSource)
            try Data([2]).write(to: conflictSource)
            let skipped = PlannedOperation(
                kind: .skipExisting,
                source: skippedSource,
                destination: nil,
                byteCount: 1,
                expectedDigest: nil,
                explanation: "Identical target exists"
            )
            let conflict = PlannedOperation(
                kind: .conflict,
                source: conflictSource,
                destination: fixture.target.appending(path: "conflict.mov"),
                byteCount: 1,
                expectedDigest: nil,
                explanation: "Requires review"
            )

            let results = await OperationExecutor().execute(
                plan: OperationPlan(operations: [skipped, conflict], createdAt: .now),
                dryRun: false
            )

            #expect(results.count == 2)
            #expect(results.allSatisfy { !$0.performed })
            #expect(results.map(\.message) == ["Identical target exists", "Requires review"])
            #expect(FileManager.default.fileExists(atPath: skippedSource.path()))
            #expect(FileManager.default.fileExists(atPath: conflictSource.path()))
            #expect(!FileManager.default.fileExists(atPath: fixture.target.appending(path: "conflict.mov").path()))
        }
    }

    @Test func `Existing destination stops execution without changing source`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let source = fixture.source.appending(path: "source.mov")
            let destination = fixture.target.appending(path: "destination.mov")
            try Data([1]).write(to: source)
            try Data([2]).write(to: destination)
            let operation = PlannedOperation(kind: .moveToLibrary, source: source, destination: destination, byteCount: 1, expectedDigest: nil, explanation: "test")

            let results = await OperationExecutor().execute(plan: OperationPlan(operations: [operation], createdAt: .now), dryRun: false)

            #expect(try Data(contentsOf: source) == Data([1]))
            #expect(try Data(contentsOf: destination) == Data([2]))
            #expect(results.first?.performed == false)
        }
    }
}

struct EmptyFolderCleanerCoverageTests {
    @Test func `Dry run simulates leaf-first cleanup without changing the source`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let emptyParent = fixture.source.appending(path: "Empty/Parent", directoryHint: .isDirectory)
            let emptyLeaf = emptyParent.appending(path: "Leaf", directoryHint: .isDirectory)
            let nonEmpty = fixture.source.appending(path: "Has Sidecar", directoryHint: .isDirectory)
            let outside = fixture.root.appending(path: "Outside", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: emptyLeaf, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: nonEmpty, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            try Data([1]).write(to: nonEmpty.appending(path: ".metadata"))
            let link = fixture.source.appending(path: "Linked Folder")
            try FileManager.default.createSymbolicLink(at: link, withDestinationURL: outside)

            let result = try await EmptyFolderCleaner().clean(root: fixture.source, dryRun: true)
            let paths = Set(result.folders.map { $0.standardizedFileURL.path() })

            #expect(!result.removed)
            #expect(paths.contains(emptyLeaf.standardizedFileURL.path()))
            #expect(paths.contains(emptyParent.standardizedFileURL.path()))
            #expect(paths.contains(fixture.source.appending(path: "Empty").standardizedFileURL.path()))
            #expect(!paths.contains(nonEmpty.standardizedFileURL.path()))
            #expect(!paths.contains(link.standardizedFileURL.path()))
            #expect(FileManager.default.fileExists(atPath: emptyLeaf.path()))
            #expect(FileManager.default.fileExists(atPath: fixture.source.path()))
        }
    }

    @Test func `Cleanup removes empty descendants but preserves root and folders with files`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let emptyLeaf = fixture.source.appending(path: "Empty/Parent/Leaf", directoryHint: .isDirectory)
            let nonEmpty = fixture.source.appending(path: "Remaining", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: emptyLeaf, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: nonEmpty, withIntermediateDirectories: true)
            try Data([1]).write(to: nonEmpty.appending(path: "notes.txt"))

            let result = try await EmptyFolderCleaner().clean(root: fixture.source, dryRun: false)

            #expect(result.removed)
            #expect(result.folders.count == 3)
            #expect(!FileManager.default.fileExists(atPath: fixture.source.appending(path: "Empty").path()))
            #expect(FileManager.default.fileExists(atPath: nonEmpty.path()))
            #expect(FileManager.default.fileExists(atPath: fixture.source.path()))
        }
    }

    @Test func `Cancelled cleanup leaves folders untouched`() async throws {
        try await TemporaryFixture.withFixture { fixture in
            let empty = fixture.source.appending(path: "Empty", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
            let task = Task {
                try await EmptyFolderCleaner().clean(root: fixture.source, dryRun: false)
            }
            task.cancel()

            await #expect(throws: CancellationError.self) {
                _ = try await task.value
            }
            #expect(FileManager.default.fileExists(atPath: empty.path()))
            #expect(FileManager.default.fileExists(atPath: fixture.source.path()))
        }
    }
}

@MainActor
struct AppModelCoverageTests {
    @Test func `App model defaults to dry run and formats a detailed report`() throws {
        let fixture = try TemporaryFixture()
        defer { fixture.remove() }
        let source = fixture.source.appending(path: "source.mov")
        let destination = fixture.target.appending(path: "destination.mov")
        let operation = PlannedOperation(kind: .moveToLibrary, source: source, destination: destination, byteCount: 1_024, expectedDigest: nil, explanation: "Unique content")
        let model = DedupAppModel()
        model.sourceURL = fixture.source
        model.targetURL = fixture.target
        model.plan = OperationPlan(operations: [operation], createdAt: .now)

        #expect(model.dryRun)
        #expect(!model.cleanEmptyFolders)
        #expect(model.result(for: operation) == nil)
        #expect(model.operationReport.contains("DRY RUN"))
        #expect(model.operationReport.contains("Empty-folder cleanup: DISABLED"))
        #expect(model.operationReport.contains(source.path()))
        #expect(model.operationReport.contains(destination.path()))
        #expect(model.operationReport.contains("Unique content"))
    }
}

@Suite(.serialized)
struct VolumeFixtureIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["DEDUP_RUN_VOLUME_TESTS"] == "1"))
    func `Configured volume fixture is accessible and destination layout can be prepared`() async throws {
        let source = URL(filePath: "/Volumes/VideoProjects/Test/TestFiles", directoryHint: .isDirectory)
        let destination = URL(filePath: "/Volumes/VideoProjects/Test/Results", directoryHint: .isDirectory)
        try DestinationLayout.ensureDirectories(at: destination)
        let result = try await MediaScanner().scan(root: source)
        #expect(result.records.isEmpty == false)
        for kind in MediaKind.allCases {
            #expect(FileManager.default.fileExists(atPath: destination.appending(path: kind.rawValue).path()))
        }
    }
}

private actor ProgressRecorder {
    private(set) var values: [AnalysisProgress] = []
    func append(_ progress: AnalysisProgress) { values.append(progress) }
}

private actor OperationProgressRecorder {
    private(set) var values: [OperationProgress] = []
    func append(_ progress: OperationProgress) { values.append(progress) }
}

private struct TemporaryFixture: Sendable {
    let root: URL
    let source: URL
    let target: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "DedupCoverage-\(UUID().uuidString)", directoryHint: .isDirectory)
        source = root.appending(path: "Source", directoryHint: .isDirectory)
        target = root.appending(path: "Target", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    }

    static func withFixture(_ body: (TemporaryFixture) async throws -> Void) async throws {
        let fixture = try TemporaryFixture()
        defer { fixture.remove() }
        try await body(fixture)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    func makeRecord(name: String, bytes: [UInt8], in directory: URL? = nil) throws -> MediaRecord {
        let url = (directory ?? source).appending(path: name)
        try Data(bytes).write(to: url)
        return try Self.record(for: url)
    }

    func makeLegacyMediaFile(name: String, bytes: [UInt8]) throws -> MediaFile {
        let url = source.appending(path: name)
        try Data(bytes).write(to: url)
        return try #require(MediaFile(fileUrl: url))
    }

    static func record(for url: URL) throws -> MediaRecord {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
        return MediaRecord(
            id: url.path(),
            url: url,
            byteCount: Int64(try #require(values.fileSize)),
            creationDate: values.creationDate ?? .distantPast,
            modificationDate: values.contentModificationDate ?? .distantPast,
            kind: try #require(MediaKind.classify(url: url, contentType: nil)),
            fileResourceIdentifier: nil
        )
    }
}

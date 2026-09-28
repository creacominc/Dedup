import CryptoKit
import Foundation
internal import UniformTypeIdentifiers

enum MediaKind: String, Codable, CaseIterable, Sendable {
    case audio = "Audio"
    case photo = "Photos"
    case video = "Videos"

    nonisolated static func classify(url: URL, contentType: UTType?) -> MediaKind? {
        if contentType?.conforms(to: .audio) == true { return .audio }
        if contentType?.conforms(to: .image) == true { return .photo }
        if contentType?.conforms(to: .video) == true || contentType?.conforms(to: .movie) == true { return .video }

        switch url.pathExtension.lowercased() {
        case "wav", "flac", "aac", "m4a", "mp3", "ogg", "wma": return .audio
        case "jpeg", "jpg", "png", "gif", "bmp", "tiff", "tif", "psd", "cr2", "cr3", "rw2", "raw", "dng", "arw", "nef", "orf", "rwz", "heic", "heif", "webp": return .photo
        case "mov", "mp4", "avi", "mkv", "wmv", "flv", "webm", "m4v", "braw", "r3d", "crm", "mpeg", "mpg": return .video
        default: return nil
        }
    }
}

struct MediaRecord: Identifiable, Hashable, Codable, Sendable {
    let id: String
    let url: URL
    let byteCount: Int64
    let creationDate: Date
    let modificationDate: Date
    let kind: MediaKind
    let fileResourceIdentifier: String?

    var displayName: String { url.lastPathComponent }

    var cacheIdentity: String {
        "\(url.path(percentEncoded: false))|\(byteCount)|\(modificationDate.timeIntervalSince1970)"
    }
}

struct ScanIssue: Identifiable, Hashable, Sendable {
    let id = UUID()
    let url: URL
    let message: String
}

struct ScanResult: Sendable {
    let records: [MediaRecord]
    let issues: [ScanIssue]
}

enum MediaScannerError: LocalizedError {
    case inaccessibleRoot(URL)

    var errorDescription: String? {
        switch self {
        case .inaccessibleRoot(let url): "Unable to inspect \(url.path(percentEncoded: false))."
        }
    }
}

struct MediaScanner: Sendable {
    nonisolated func scan(root: URL) async throws -> ScanResult {
        try await Task.detached(priority: .userInitiated) {
            try Self.scanSynchronously(root: root)
        }.value
    }

    nonisolated private static func scanSynchronously(root: URL) throws -> ScanResult {
        let keys: Set<URLResourceKey> = [
            .contentModificationDateKey, .contentTypeKey, .creationDateKey,
            .fileResourceIdentifierKey, .fileSizeKey, .isDirectoryKey,
            .isRegularFileKey, .isSymbolicLinkKey, .volumeIdentifierKey
        ]
        let rootValues = try root.resourceValues(forKeys: keys)
        guard rootValues.isDirectory == true else { throw MediaScannerError.inaccessibleRoot(root) }
        let rootVolume = String(describing: rootValues.volumeIdentifier)
        let manager = FileManager()
        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            throw MediaScannerError.inaccessibleRoot(root)
        }

        var records: [MediaRecord] = []
        var issues: [ScanIssue] = []
        var seenIdentities = Set<String>()

        for case let url as URL in enumerator {
            try Task.checkCancellation()
            do {
                let values = try url.resourceValues(forKeys: keys)
                let isLink = values.isSymbolicLink == true
                let isOtherVolume = String(describing: values.volumeIdentifier) != rootVolume

                if values.isDirectory == true {
                    if isLink || isOtherVolume {
                        enumerator.skipDescendants()
                    }
                    continue
                }
                guard !isLink, !isOtherVolume, values.isRegularFile == true else { continue }
                guard let kind = MediaKind.classify(url: url, contentType: values.contentType) else { continue }

                let size = Int64(values.fileSize ?? 0)
                let modified = values.contentModificationDate ?? .distantPast
                let created = min(values.creationDate ?? modified, modified)
                let resourceID = values.fileResourceIdentifier.map { String(describing: $0) }
                let identity = resourceID.map { "\(rootVolume)|\($0)" } ?? url.standardizedFileURL.path(percentEncoded: false)
                guard seenIdentities.insert(identity).inserted else { continue }

                records.append(MediaRecord(
                    id: identity,
                    url: url,
                    byteCount: size,
                    creationDate: created,
                    modificationDate: modified,
                    kind: kind,
                    fileResourceIdentifier: resourceID
                ))
            } catch {
                issues.append(ScanIssue(url: url, message: error.localizedDescription))
                if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    enumerator.skipDescendants()
                }
            }
        }
        return ScanResult(records: records, issues: issues)
    }
}

enum HashingError: LocalizedError, Sendable {
    case changedDuringRead(URL)
    case shortRead(URL, expected: Int64, actual: Int64)

    var errorDescription: String? {
        switch self {
        case .changedDuringRead(let url): "The file changed while it was being read: \(url.path(percentEncoded: false))"
        case .shortRead(let url, let expected, let actual): "Short read for \(url.path(percentEncoded: false)); expected \(expected) bytes and read \(actual)."
        }
    }
}

struct HashCheckpoint: Hashable, Codable, Sendable {
    let byteCount: Int64
    let digest: String
}

struct ProgressiveHasher: Sendable {
    nonisolated static let defaultCheckpoints: [Int64] = [
        256,
        4 * 1_024,
        1 * 1_024 * 1_024,
        64 * 1_024 * 1_024,
        1 * 1_024 * 1_024 * 1_024
    ]
    nonisolated private static let bufferSize = 4 * 1_024 * 1_024

    nonisolated func prefixDigest(for record: MediaRecord, byteLimit: Int64) async throws -> HashCheckpoint {
        try await Task.detached(priority: .utility) {
            try Self.hash(record: record, byteLimit: min(byteLimit, record.byteCount))
        }.value
    }

    nonisolated func fullDigest(for record: MediaRecord) async throws -> HashCheckpoint {
        try await prefixDigest(for: record, byteLimit: record.byteCount)
    }

    nonisolated func fullDigest(url: URL, expectedSize: Int64) async throws -> HashCheckpoint {
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey])
        let record = MediaRecord(
            id: url.standardizedFileURL.path(percentEncoded: false),
            url: url,
            byteCount: expectedSize,
            creationDate: .distantPast,
            modificationDate: values.contentModificationDate ?? .distantPast,
            kind: .video,
            fileResourceIdentifier: nil
        )
        return try await prefixDigest(for: record, byteLimit: expectedSize)
    }

    nonisolated private static func hash(record: MediaRecord, byteLimit: Int64) throws -> HashCheckpoint {
        let before = try fileSnapshot(at: record.url)
        guard before.size == record.byteCount,
              before.modified == record.modificationDate else {
            throw HashingError.changedDuringRead(record.url)
        }

        let handle = try FileHandle(forReadingFrom: record.url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var totalRead: Int64 = 0

        while totalRead < byteLimit {
            try Task.checkCancellation()
            let requested = Int(min(Int64(bufferSize), byteLimit - totalRead))
            guard let data = try handle.read(upToCount: requested), !data.isEmpty else { break }
            hasher.update(data: data)
            totalRead += Int64(data.count)
        }
        guard totalRead == byteLimit else {
            throw HashingError.shortRead(record.url, expected: byteLimit, actual: totalRead)
        }

        let after = try fileSnapshot(at: record.url)
        guard before == after else {
            throw HashingError.changedDuringRead(record.url)
        }
        return HashCheckpoint(
            byteCount: byteLimit,
            digest: hasher.finalize().map { String(format: "%02x", $0) }.joined()
        )
    }

    nonisolated private static func fileSnapshot(at url: URL) throws -> (size: Int64, modified: Date) {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false))
        return (
            size: (attributes[.size] as? NSNumber)?.int64Value ?? -1,
            modified: attributes[.modificationDate] as? Date ?? .distantPast
        )
    }
}

actor HashCache {
    private struct Entry: Codable {
        let size: Int64
        let modified: Date
        var digests: [String: String]
    }

    private var entries: [String: Entry] = [:]
    private let storeURL: URL

    init(storeURL: URL? = nil) {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.storeURL = storeURL ?? base.appending(path: "Dedup/hash-cache.json")
        if let data = try? Data(contentsOf: self.storeURL),
           let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) {
            entries = decoded
        }
    }

    func digest(for record: MediaRecord, byteCount: Int64) -> String? {
        guard let entry = entries[record.url.path(percentEncoded: false)],
              entry.size == record.byteCount,
              entry.modified == record.modificationDate else { return nil }
        return entry.digests[String(byteCount)]
    }

    func store(_ checkpoint: HashCheckpoint, for record: MediaRecord) async {
        let key = record.url.path(percentEncoded: false)
        var entry = entries[key] ?? Entry(size: record.byteCount, modified: record.modificationDate, digests: [:])
        guard entry.size == record.byteCount, entry.modified == record.modificationDate else {
            entries[key] = Entry(size: record.byteCount, modified: record.modificationDate, digests: [String(checkpoint.byteCount): checkpoint.digest])
            await persist()
            return
        }
        entry.digests[String(checkpoint.byteCount)] = checkpoint.digest
        entries[key] = entry
        await persist()
    }

    private func persist() async {
        do {
            try FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            // Cache persistence is an optimization; analysis results remain valid without it.
        }
    }
}

struct DuplicateGroupResult: Identifiable, Hashable, Sendable {
    let digest: String
    let files: [MediaRecord]
    var id: String { digest }
}

struct AnalysisReport: Sendable {
    let sourceFiles: [MediaRecord]
    let targetFiles: [MediaRecord]
    let uniqueSourceFiles: [MediaRecord]
    let duplicateGroups: [DuplicateGroupResult]
    let issues: [ScanIssue]
}

struct AnalysisProgress: Sendable {
    let phase: String
    let completed: Int
    let total: Int
}

actor DeduplicationEngine {
    private let scanner = MediaScanner()
    private let hasher = ProgressiveHasher()
    private let cache = HashCache()
    private let maximumConcurrentReads = 4

    func analyze(
        source: URL,
        target: URL,
        progress: @escaping @Sendable (AnalysisProgress) async -> Void
    ) async throws -> AnalysisReport {
        await progress(AnalysisProgress(phase: "Scanning source", completed: 0, total: 2))
        async let sourceScan = scanner.scan(root: source)
        async let targetScan = scanner.scan(root: target)
        let (sourceResult, targetResult) = try await (sourceScan, targetScan)
        await progress(AnalysisProgress(phase: "Comparing equal-size candidates", completed: 0, total: sourceResult.records.count))

        let sourceIDs = Set(sourceResult.records.map(\.id))
        let allRecords = sourceResult.records + targetResult.records
        let bySize = Dictionary(grouping: allRecords, by: \.byteCount)
        var uniqueIDs = Set<String>()
        var duplicates: [DuplicateGroupResult] = []
        var issues = sourceResult.issues + targetResult.issues
        var processed = 0

        for (_, sameSizeFiles) in bySize {
            try Task.checkCancellation()
            if sameSizeFiles.count == 1 {
                if sourceIDs.contains(sameSizeFiles[0].id) { uniqueIDs.insert(sameSizeFiles[0].id) }
                processed += sameSizeFiles.count
                continue
            }

            var candidates = [sameSizeFiles]
            let stages = ProgressiveHasher.defaultCheckpoints.filter { $0 < sameSizeFiles[0].byteCount } + [sameSizeFiles[0].byteCount]
            for stage in stages {
                var nextCandidates: [[MediaRecord]] = []
                for candidateGroup in candidates {
                    let results = await hashInBatches(
                        candidateGroup,
                        byteCount: stage,
                        completed: min(processed, sourceResult.records.count),
                        total: sourceResult.records.count,
                        progress: progress
                    )
                    var grouped: [String: [MediaRecord]] = [:]
                    for (record, digest, errorMessage) in results {
                        if let digest {
                            grouped[digest, default: []].append(record)
                        } else if let errorMessage {
                            issues.append(ScanIssue(url: record.url, message: errorMessage))
                        }
                    }
                    for group in grouped.values {
                        if group.count == 1 {
                            if sourceIDs.contains(group[0].id) { uniqueIDs.insert(group[0].id) }
                        } else {
                            nextCandidates.append(group)
                        }
                    }
                }
                candidates = nextCandidates
                if candidates.isEmpty { break }
            }

            for group in candidates where group.count > 1 {
                let digest = await cachedDigest(for: group[0], byteCount: group[0].byteCount) ?? ""
                guard !digest.isEmpty else { continue }
                duplicates.append(DuplicateGroupResult(digest: digest, files: group.sorted { $0.url.path() < $1.url.path() }))
            }
            processed += sameSizeFiles.count
            await progress(AnalysisProgress(phase: "Comparing equal-size candidates", completed: min(processed, sourceResult.records.count), total: sourceResult.records.count))
        }

        let duplicateIDs = Set(duplicates.flatMap(\.files).map(\.id))
        for sourceFile in sourceResult.records where !duplicateIDs.contains(sourceFile.id) {
            uniqueIDs.insert(sourceFile.id)
        }
        return AnalysisReport(
            sourceFiles: sourceResult.records,
            targetFiles: targetResult.records,
            uniqueSourceFiles: sourceResult.records.filter { uniqueIDs.contains($0.id) },
            duplicateGroups: duplicates.sorted { ($0.files.first?.byteCount ?? 0) > ($1.files.first?.byteCount ?? 0) },
            issues: issues
        )
    }

    private func hashInBatches(
        _ records: [MediaRecord],
        byteCount: Int64,
        completed: Int,
        total: Int,
        progress: @escaping @Sendable (AnalysisProgress) async -> Void
    ) async -> [(MediaRecord, String?, String?)] {
        var output: [(MediaRecord, String?, String?)] = []
        for start in stride(from: 0, to: records.count, by: maximumConcurrentReads) {
            let batch = Array(records[start..<min(start + maximumConcurrentReads, records.count)])
            if let first = batch.first {
                let fileSize = ByteCountFormatter.string(fromByteCount: first.byteCount, countStyle: .file)
                let checkpointSize = ByteCountFormatter.string(fromByteCount: min(byteCount, first.byteCount), countStyle: .file)
                let additionalFiles = batch.count > 1 ? " + \(batch.count - 1) more" : ""
                await progress(AnalysisProgress(
                    phase: "Comparing \(fileSize) files — hashing \(first.displayName)\(additionalFiles) through \(checkpointSize)",
                    completed: completed,
                    total: total
                ))
            }
            let values = await withTaskGroup(of: (MediaRecord, String?, String?).self) { group in
                for record in batch {
                    group.addTask { [hasher, cache] in
                        if let cached = await cache.digest(for: record, byteCount: byteCount) {
                            return (record, cached, nil)
                        }
                        do {
                            let checkpoint = try await hasher.prefixDigest(for: record, byteLimit: byteCount)
                            await cache.store(checkpoint, for: record)
                            return (record, checkpoint.digest, nil)
                        } catch {
                            return (record, nil, error.localizedDescription)
                        }
                    }
                }
                var batchResults: [(MediaRecord, String?, String?)] = []
                for await result in group {
                    batchResults.append(result)
                }
                return batchResults
            }
            output.append(contentsOf: values)
        }
        return output
    }

    private func cachedDigest(for record: MediaRecord, byteCount: Int64) async -> String? {
        await cache.digest(for: record, byteCount: byteCount)
    }
}

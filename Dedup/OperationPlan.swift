import CryptoKit
import Foundation

enum PlannedOperationKind: String, Codable, Sendable {
    case moveToLibrary = "Move to library"
    case quarantineDuplicate = "Quarantine duplicate"
    case skipExisting = "Skip; copy already exists in target"
    case conflict = "Conflict requiring review"
}

struct PlannedOperation: Identifiable, Hashable, Sendable {
    let id = UUID()
    let kind: PlannedOperationKind
    let source: URL
    let destination: URL?
    let byteCount: Int64
    let expectedDigest: String?
    let explanation: String
}

struct OperationPlan: Sendable {
    let operations: [PlannedOperation]
    let createdAt: Date
}

enum DestinationLayout {
    static func ensureDirectories(at root: URL, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        for kind in MediaKind.allCases {
            try fileManager.createDirectory(
                at: root.appending(path: kind.rawValue, directoryHint: .isDirectory),
                withIntermediateDirectories: true
            )
        }
    }
}

struct OperationPlanner: Sendable {
    func makePlan(report: AnalysisReport, sourceRoot: URL, targetRoot: URL) -> OperationPlan {
        let sourceIDs = Set(report.sourceFiles.map(\.id))
        let targetIDs = Set(report.targetFiles.map(\.id))
        var operations: [PlannedOperation] = report.uniqueSourceFiles.map { file in
            let proposedDestination = destination(for: file, root: targetRoot)
            let hasCollision = FileManager.default.fileExists(atPath: proposedDestination.path(percentEncoded: false))
            return PlannedOperation(
                kind: hasCollision ? .conflict : .moveToLibrary,
                source: file.url,
                destination: proposedDestination,
                byteCount: file.byteCount,
                expectedDigest: nil,
                explanation: hasCollision ? "A different file already occupies the proposed destination." : "No target file has identical content."
            )
        }

        for group in report.duplicateGroups {
            let sources = group.files.filter { sourceIDs.contains($0.id) }
            let targets = group.files.filter { targetIDs.contains($0.id) }
            if !targets.isEmpty {
                operations.append(contentsOf: sources.map { file in
                    PlannedOperation(
                        kind: .quarantineDuplicate,
                        source: file.url,
                        destination: quarantineDestination(for: file, sourceRoot: sourceRoot, targetRoot: targetRoot),
                        byteCount: file.byteCount,
                        expectedDigest: group.digest,
                        explanation: "An exact, fully hashed copy already exists in the target; quarantine this source copy."
                    )
                })
            } else if let keeper = sources.min(by: { $0.creationDate < $1.creationDate }) {
                operations.append(PlannedOperation(
                    kind: .moveToLibrary,
                    source: keeper.url,
                    destination: destination(for: keeper, root: targetRoot),
                    byteCount: keeper.byteCount,
                    expectedDigest: group.digest,
                    explanation: "Selected as the oldest source copy in an exact-duplicate group."
                ))
                operations.append(contentsOf: sources.filter { $0.id != keeper.id }.map { file in
                    PlannedOperation(
                        kind: .quarantineDuplicate,
                        source: file.url,
                        destination: quarantineDestination(for: file, sourceRoot: sourceRoot, targetRoot: targetRoot),
                        byteCount: file.byteCount,
                        expectedDigest: group.digest,
                        explanation: "Exact duplicate of \(keeper.displayName); quarantine instead of deleting."
                    )
                })
            }
        }
        return OperationPlan(operations: operations.sorted { $0.source.path() < $1.source.path() }, createdAt: .now)
    }

    private func destination(for file: MediaRecord, root: URL) -> URL {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: file.creationDate)
        return root
            .appending(path: file.kind.rawValue, directoryHint: .isDirectory)
            .appending(path: String(format: "%04d", components.year ?? 1970), directoryHint: .isDirectory)
            .appending(path: String(format: "%02d", components.month ?? 1), directoryHint: .isDirectory)
            .appending(path: String(format: "%02d", components.day ?? 1), directoryHint: .isDirectory)
            .appending(path: file.displayName)
    }

    private func quarantineDestination(for file: MediaRecord, sourceRoot: URL, targetRoot: URL) -> URL {
        let relative = file.url.path(percentEncoded: false).dropFirst(sourceRoot.path(percentEncoded: false).count).trimmingPrefix("/")
        return targetRoot.appending(path: ".Dedup Quarantine", directoryHint: .isDirectory).appending(path: relative)
    }
}

enum OperationExecutionError: LocalizedError {
    case destinationExists(URL)
    case verificationFailed(URL)

    var errorDescription: String? {
        switch self {
        case .destinationExists(let url): "Destination already exists: \(url.path(percentEncoded: false))"
        case .verificationFailed(let url): "The staged copy failed checksum verification: \(url.path(percentEncoded: false))"
        }
    }
}

struct OperationResult: Sendable {
    let operation: PlannedOperation
    let performed: Bool
    let message: String
}

struct OperationProgress: Sendable {
    let operation: PlannedOperation
    let completed: Int
    let total: Int
    let message: String
    let result: OperationResult?
}

actor OperationExecutor {
    private let forceVerifiedCopy: Bool

    init(forceVerifiedCopy: Bool = false) {
        self.forceVerifiedCopy = forceVerifiedCopy
    }

    func execute(
        plan: OperationPlan,
        dryRun: Bool,
        progress: @escaping @Sendable (OperationProgress) async -> Void = { _ in }
    ) async -> [OperationResult] {
        var results: [OperationResult] = []
        for (index, operation) in plan.operations.enumerated() {
            if Task.isCancelled { break }
            await progress(OperationProgress(
                operation: operation,
                completed: index,
                total: plan.operations.count,
                message: "Starting \(operation.source.lastPathComponent)…",
                result: nil
            ))
            if dryRun || operation.kind == .skipExisting || operation.kind == .conflict {
                let result = OperationResult(operation: operation, performed: false, message: dryRun ? "Dry run — no filesystem change" : operation.explanation)
                results.append(result)
                await progress(OperationProgress(operation: operation, completed: index + 1, total: plan.operations.count, message: result.message, result: result))
                continue
            }
            do {
                let completionMessage = try await performVerifiedTransfer(operation) { message in
                    await progress(OperationProgress(operation: operation, completed: index, total: plan.operations.count, message: message, result: nil))
                }
                let result = OperationResult(operation: operation, performed: true, message: completionMessage)
                results.append(result)
                await progress(OperationProgress(operation: operation, completed: index + 1, total: plan.operations.count, message: result.message, result: result))
            } catch is CancellationError {
                let result = OperationResult(operation: operation, performed: false, message: "Cancelled — source left unchanged")
                results.append(result)
                await progress(OperationProgress(operation: operation, completed: index, total: plan.operations.count, message: result.message, result: result))
                break
            } catch {
                let result = OperationResult(operation: operation, performed: false, message: error.localizedDescription)
                results.append(result)
                await progress(OperationProgress(operation: operation, completed: index + 1, total: plan.operations.count, message: result.message, result: result))
                break
            }
        }
        return results
    }

    private func performVerifiedTransfer(
        _ operation: PlannedOperation,
        progress: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        guard let destination = operation.destination else { throw CocoaError(.fileNoSuchFile) }
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path(percentEncoded: false)) else {
            throw OperationExecutionError.destinationExists(destination)
        }
        try manager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let sameVolume: Bool
        if forceVerifiedCopy {
            sameVolume = false
        } else {
            sameVolume = try isOnSameVolume(operation.source, destination.deletingLastPathComponent())
        }

        if sameVolume {
            await progress("Moving \(operation.source.lastPathComponent) on the same filesystem…")
            do {
                try Task.checkCancellation()
                try manager.moveItem(at: operation.source, to: destination)
                return "Moved atomically on the same filesystem"
            } catch {
                let sourceStillExists = manager.fileExists(atPath: operation.source.path(percentEncoded: false))
                let destinationExists = manager.fileExists(atPath: destination.path(percentEncoded: false))
                if !sourceStillExists && destinationExists {
                    return "Moved on the same filesystem"
                }
                guard sourceStillExists, !destinationExists else { throw error }
                await progress("Move failed; falling back to verified copy for \(operation.source.lastPathComponent)…")
            }
        } else {
            await progress("Different filesystems; copying \(operation.source.lastPathComponent)…")
        }

        let staging = destination.deletingLastPathComponent().appending(path: ".\(destination.lastPathComponent).dedup-part-\(UUID().uuidString)")
        do {
            try await copyToStaging(operation: operation, staging: staging, progress: progress)
            let sourceDigest = try await hashForVerification(
                url: operation.source,
                expectedSize: operation.byteCount,
                phase: "Hashing source",
                displayName: operation.source.lastPathComponent,
                progress: progress
            )
            let stagedDigest = try await hashForVerification(
                url: staging,
                expectedSize: operation.byteCount,
                phase: "Hashing staged copy",
                displayName: operation.source.lastPathComponent,
                progress: progress
            )
            guard sourceDigest == stagedDigest,
                  operation.expectedDigest == nil || operation.expectedDigest == sourceDigest else {
                throw OperationExecutionError.verificationFailed(staging)
            }
            let attributes = try manager.attributesOfItem(atPath: operation.source.path(percentEncoded: false))
            try manager.setAttributes(attributes.filter { $0.key == .creationDate || $0.key == .modificationDate }, ofItemAtPath: staging.path(percentEncoded: false))
            await progress("Committing \(operation.source.lastPathComponent)…")
            try manager.moveItem(at: staging, to: destination)
            await progress("Removing verified source \(operation.source.lastPathComponent)…")
            try manager.removeItem(at: operation.source)
            return "Copied, verified, and committed"
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }
    }

    private func isOnSameVolume(_ source: URL, _ destinationDirectory: URL) throws -> Bool {
        let sourceValues = try source.resourceValues(forKeys: [.volumeIdentifierKey])
        let destinationValues = try destinationDirectory.resourceValues(forKeys: [.volumeIdentifierKey])
        guard let sourceIdentifier = sourceValues.volumeIdentifier,
              let destinationIdentifier = destinationValues.volumeIdentifier else {
            return false
        }
        return String(describing: sourceIdentifier) == String(describing: destinationIdentifier)
    }

    private func copyToStaging(
        operation: PlannedOperation,
        staging: URL,
        progress: @escaping @Sendable (String) async -> Void
    ) async throws {
        let manager = FileManager.default
        guard manager.createFile(atPath: staging.path(percentEncoded: false), contents: nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let sourceHandle = try FileHandle(forReadingFrom: operation.source)
        let destinationHandle = try FileHandle(forWritingTo: staging)
        defer {
            try? sourceHandle.close()
            try? destinationHandle.close()
        }

        let bufferSize = 1 * 1_024 * 1_024
        let reportingInterval: Int64 = 16 * 1_024 * 1_024
        var copied: Int64 = 0
        var nextReport: Int64 = 0

        while true {
            try Task.checkCancellation()
            guard let data = try sourceHandle.read(upToCount: bufferSize), !data.isEmpty else { break }
            try destinationHandle.write(contentsOf: data)
            copied += Int64(data.count)

            if copied >= nextReport || copied == operation.byteCount {
                let percent = operation.byteCount > 0 ? Int((Double(copied) / Double(operation.byteCount)) * 100) : 100
                let copiedText = ByteCountFormatter.string(fromByteCount: copied, countStyle: .file)
                let totalText = ByteCountFormatter.string(fromByteCount: operation.byteCount, countStyle: .file)
                await progress("Copying \(operation.source.lastPathComponent): \(copiedText) of \(totalText) (\(percent)%)")
                nextReport = copied + reportingInterval
            }
        }
        try Task.checkCancellation()
        guard copied == operation.byteCount else {
            throw HashingError.shortRead(operation.source, expected: operation.byteCount, actual: copied)
        }
        try destinationHandle.synchronize()
    }

    private func hashForVerification(
        url: URL,
        expectedSize: Int64,
        phase: String,
        displayName: String,
        progress: @escaping @Sendable (String) async -> Void
    ) async throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let bufferSize = 1 * 1_024 * 1_024
        let reportingInterval: Int64 = 16 * 1_024 * 1_024
        var hasher = SHA256()
        var hashed: Int64 = 0
        var nextReport: Int64 = 0

        while true {
            try Task.checkCancellation()
            guard let data = try handle.read(upToCount: bufferSize), !data.isEmpty else { break }
            hasher.update(data: data)
            hashed += Int64(data.count)
            if hashed >= nextReport || hashed == expectedSize {
                let percent = expectedSize > 0 ? Int((Double(hashed) / Double(expectedSize)) * 100) : 100
                let hashedText = ByteCountFormatter.string(fromByteCount: hashed, countStyle: .file)
                let totalText = ByteCountFormatter.string(fromByteCount: expectedSize, countStyle: .file)
                await progress("\(phase) \(displayName): \(hashedText) of \(totalText) (\(percent)%)")
                nextReport = hashed + reportingInterval
            }
        }
        try Task.checkCancellation()
        guard hashed == expectedSize else {
            throw HashingError.shortRead(url, expected: expectedSize, actual: hashed)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

private extension String {
    func trimmingPrefix(_ prefix: Character) -> String {
        var result = self
        while result.first == prefix { result.removeFirst() }
        return result
    }
}

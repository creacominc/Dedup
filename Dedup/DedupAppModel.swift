import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DedupAppModel {
    enum Activity: Equatable { case idle, indexing, analyzing, executing }

    struct LimitPreview: Equatable {
        let includedFiles: Int
        let includedBytes: Int64
        let excludedFiles: Int
        let excludedBytes: Int64
    }

    var sourceURL: URL?
    var targetURL: URL?
    var report: AnalysisReport?
    var plan: OperationPlan?
    var results: [OperationResult] = []
    var issues: [ScanIssue] = []
    var activity: Activity = .idle
    var status = "Choose a source and the Originals target folder."
    var progressCompleted = 0
    var progressTotal = 0
    var lastActivityAt: Date?
    var dryRun = true
    var cleanEmptyFolders = false
    var limitsSourceFiles = false
    var maximumSourceFiles = 100
    var limitsSourceSize = false
    var maximumSourceGigabytes = 100
    var limitsIndividualFileSize = false
    var maximumIndividualFileGigabytes = 100
    var cleanupResult: EmptyFolderCleanupResult?
    var selectedSection: SidebarSection? = .overview
    var analysisIndex: AnalysisIndex?

    private let engine = DeduplicationEngine()
    private let executor = OperationExecutor()
    private let emptyFolderCleaner = EmptyFolderCleaner()
    private var workTask: Task<Void, Never>?
    private var destinationIndexTask: Task<ScanResult, Error>?
    private var destinationIndexResult: ScanResult?
    private var indexGeneration = UUID()

    init() {
        sourceURL = Self.restoreBookmark(named: "sourceBookmark")
        targetURL = Self.restoreBookmark(named: "targetBookmark")
    }

    func chooseSource() {
        guard let url = chooseFolder(
            prompt: "Select a source folder containing media",
            startingAt: sourceURL
        ) else { return }
        sourceURL = url
        Self.saveBookmark(url, named: "sourceBookmark")
        resetAnalysis()
    }

    func chooseTarget() {
        guard let url = chooseFolder(
            prompt: "Select /Volumes/VideoProjects/Originals",
            startingAt: targetURL
        ) else { return }
        targetURL = url
        Self.saveBookmark(url, named: "targetBookmark")
        resetAnalysis()
    }

    var hasFolderIndex: Bool { analysisIndex != nil }

    var primaryActionTitle: LocalizedStringResource {
        hasFolderIndex ? "Analyze Checksums" : "Index Folders"
    }

    var limitPreview: LimitPreview? {
        guard let analysisIndex else { return nil }
        let selected = currentLimits.applying(
            toRecordsSortedByDescendingSize: analysisIndex.sourceResult.records
        )
        let selectedBytes = selected.reduce(Int64.zero) { $0 + $1.byteCount }
        return LimitPreview(
            includedFiles: selected.count,
            includedBytes: selectedBytes,
            excludedFiles: analysisIndex.sourceResult.records.count - selected.count,
            excludedBytes: analysisIndex.sourceByteCount - selectedBytes
        )
    }

    func primaryAction() {
        if hasFolderIndex {
            analyzeChecksums()
        } else {
            indexFolders()
        }
    }

    func indexFolders() {
        guard let sourceURL, let targetURL, activity == .idle else { return }
        guard locationsAreValid(source: sourceURL, target: targetURL) else {
            status = "The target cannot be the source or a folder inside the source."
            return
        }
        resetAnalysis(keepStatus: true)
        let generation = indexGeneration
        activity = .indexing
        status = "Indexing source folder…"
        progressCompleted = 0
        progressTotal = 1

        workTask = Task { [weak self] in
            guard let self else { return }
            let sourceAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if sourceAccess { sourceURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let sourceResult = try await engine.indexSource(root: sourceURL)
                try Task.checkCancellation()
                guard generation == self.indexGeneration else { return }

                let index = AnalysisIndex(
                    sourceResult: sourceResult,
                    targetResult: ScanResult(records: [], issues: [])
                )
                self.analysisIndex = index
                self.presetLimits(from: index)
                self.issues = sourceResult.issues
                self.progressCompleted = 1

                let smallest = index.smallestSourceFileByteCount ?? 0
                let largest = index.largestSourceFileByteCount ?? 0
                let kinds = Set(sourceResult.records.map(\.kind))
                if kinds.isEmpty {
                    self.status = "Source index complete: no supported media files found."
                } else {
                    self.status = "Source index complete: \(sourceResult.records.count) files, \(ByteCountFormatter.string(fromByteCount: index.sourceByteCount, countStyle: .file)); file sizes \(ByteCountFormatter.string(fromByteCount: smallest, countStyle: .file))–\(ByteCountFormatter.string(fromByteCount: largest, countStyle: .file)). Indexing matching destination folders in the background."
                }
                self.startDestinationIndex(
                    targetURL: targetURL,
                    kinds: kinds,
                    generation: generation
                )
            } catch is CancellationError {
                if generation == self.indexGeneration {
                    self.status = "Indexing cancelled."
                }
            } catch {
                if generation == self.indexGeneration {
                    self.status = "Indexing failed: \(error.localizedDescription)"
                }
            }
            if generation == self.indexGeneration {
                self.activity = .idle
                self.workTask = nil
            }
        }
    }

    private func startDestinationIndex(
        targetURL: URL,
        kinds: Set<MediaKind>,
        generation: UUID
    ) {
        destinationIndexTask = Task { [weak self] in
            guard let self else { throw CancellationError() }
            let targetAccess = targetURL.startAccessingSecurityScopedResource()
            defer {
                if targetAccess { targetURL.stopAccessingSecurityScopedResource() }
            }

            do {
                let result = try await engine.indexTarget(root: targetURL, kinds: kinds)
                try Task.checkCancellation()
                guard generation == self.indexGeneration else { throw CancellationError() }

                self.destinationIndexResult = result
                self.issues = (self.analysisIndex?.sourceResult.issues ?? []) + result.issues
                if self.activity == .idle {
                    self.status = "Source and matching destination folders are indexed. Set limits, then analyze checksums."
                }
                return result
            } catch {
                if generation == self.indexGeneration, !(error is CancellationError) {
                    self.status = "Destination indexing failed: \(error.localizedDescription)"
                }
                throw error
            }
        }
    }

    func analyzeChecksums() {
        guard let sourceURL, let targetURL, let sourceIndex = analysisIndex, activity == .idle else { return }
        report = nil
        plan = nil
        results = []
        issues = sourceIndex.sourceResult.issues
        activity = .analyzing
        status = "Starting checksum analysis…"

        workTask = Task { [weak self] in
            guard let self else { return }
            let sourceAccess = sourceURL.startAccessingSecurityScopedResource()
            let targetAccess = targetURL.startAccessingSecurityScopedResource()
            defer {
                if sourceAccess { sourceURL.stopAccessingSecurityScopedResource() }
                if targetAccess { targetURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let targetResult: ScanResult
                if let destinationIndexResult {
                    targetResult = destinationIndexResult
                } else if let destinationIndexTask {
                    self.status = "Waiting for destination indexing to complete…"
                    targetResult = try await destinationIndexTask.value
                } else {
                    throw CancellationError()
                }
                try Task.checkCancellation()

                let completedIndex = AnalysisIndex(
                    sourceResult: sourceIndex.sourceResult,
                    targetResult: targetResult
                )
                self.analysisIndex = completedIndex
                let report = try await engine.analyze(index: completedIndex, limits: currentLimits) { progress in
                    await MainActor.run {
                        self.status = progress.phase
                        self.progressCompleted = progress.completed
                        self.progressTotal = progress.total
                    }
                }
                try Task.checkCancellation()
                self.report = report
                self.issues = report.issues
                self.plan = OperationPlanner().makePlan(report: report, sourceRoot: sourceURL, targetRoot: targetURL)
                let selection = report.isSourceLimited
                    ? " Selected \(report.sourceFiles.count) files (\(ByteCountFormatter.string(fromByteCount: report.selectedSourceByteCount, countStyle: .file))); excluded \(report.excludedSourceFileCount) files (\(ByteCountFormatter.string(fromByteCount: report.excludedSourceByteCount, countStyle: .file)))."
                    : ""
                self.status = "Analysis complete: \(report.duplicateGroups.count) exact duplicate groups and \(report.uniqueSourceFiles.count) unique source files.\(selection)"
                self.selectedSection = .plan
            } catch is CancellationError {
                self.status = "Analysis cancelled."
            } catch {
                self.status = "Analysis failed: \(error.localizedDescription)"
            }
            self.activity = .idle
            self.workTask = nil
        }
    }

    func executePlan() {
        guard let plan, let sourceURL, let targetURL, activity == .idle else { return }
        let isDryRun = dryRun
        let shouldCleanEmptyFolders = cleanEmptyFolders
        activity = .executing
        status = isDryRun ? "Running dry run…" : "Executing verified transfers…"
        results = []
        cleanupResult = nil
        workTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.analysisIndex = nil
                self.activity = .idle
                self.workTask = nil
            }
            let sourceAccess = sourceURL.startAccessingSecurityScopedResource()
            let targetAccess = targetURL.startAccessingSecurityScopedResource()
            defer {
                if sourceAccess { sourceURL.stopAccessingSecurityScopedResource() }
                if targetAccess { targetURL.stopAccessingSecurityScopedResource() }
            }
            do {
                try DestinationLayout.ensureDirectories(at: targetURL)
            } catch {
                self.status = "Could not prepare the destination: \(error.localizedDescription)"
                return
            }
            self.progressCompleted = 0
            self.progressTotal = plan.operations.count
            let output = await executor.execute(plan: plan, dryRun: isDryRun) { update in
                await MainActor.run {
                    self.progressCompleted = update.completed
                    self.progressTotal = update.total
                    self.lastActivityAt = .now
                    self.status = "\(isDryRun ? "Dry run" : "Executing verified transfers") — \(update.message) (\(update.completed) of \(update.total))"
                    self.updateResult(for: update.operation, message: update.message, finalResult: update.result)
                }
            }
            self.results = output
            if Task.isCancelled {
                self.status = "Execution cancelled. Partial staging data was removed and the source was left unchanged."
            } else if shouldCleanEmptyFolders && self.completedSuccessfully(plan: plan, results: output, dryRun: isDryRun) {
                do {
                    let cleanup = try await self.emptyFolderCleaner.clean(root: sourceURL, dryRun: isDryRun) { message in
                        await MainActor.run {
                            self.lastActivityAt = .now
                            self.status = message
                        }
                    }
                    self.cleanupResult = cleanup
                    let action = isDryRun ? "would be removed" : "removed"
                    self.status = "\(isDryRun ? "Dry run complete" : "Execution complete"): \(output.count(where: \.performed)) verified transfers; \(cleanup.folders.count) empty folders \(action)."
                } catch is CancellationError {
                    self.status = "Empty-folder cleanup cancelled."
                } catch {
                    self.status = "File operations completed, but empty-folder cleanup failed: \(error.localizedDescription)"
                }
            } else {
                self.status = isDryRun ? "Dry run complete; no files changed." : "Execution complete: \(output.count(where: \.performed)) verified transfers."
            }
        }
    }

    func cancel() {
        workTask?.cancel()
        destinationIndexTask?.cancel()
        lastActivityAt = .now
        status = "Cancelling current file safely…"
    }

    func result(for operation: PlannedOperation) -> OperationResult? {
        results.first { $0.operation.id == operation.id }
    }

    private func updateResult(for operation: PlannedOperation, message: String, finalResult: OperationResult?) {
        let updated = finalResult ?? OperationResult(operation: operation, performed: false, message: message)
        if let index = results.firstIndex(where: { $0.operation.id == operation.id }) {
            results[index] = updated
        } else {
            results.append(updated)
        }
    }

    var operationReport: String {
        guard let plan else { return "No operation plan is available." }
        let header = [
            "Dedup operation report",
            "Created: \(plan.createdAt.formatted(date: .numeric, time: .standard))",
            "Mode: \(dryRun ? "DRY RUN — no media files changed" : "EXECUTION")",
            "Source: \(sourceURL?.path(percentEncoded: false) ?? "Not selected")",
            "Destination: \(targetURL?.path(percentEncoded: false) ?? "Not selected")",
            "Operations: \(plan.operations.count)",
            "Empty-folder cleanup: \(cleanEmptyFolders ? "ENABLED" : "DISABLED")",
            ""
        ]
        let lines = plan.operations.enumerated().map { index, operation in
            let destination = operation.destination?.path(percentEncoded: false) ?? "—"
            let result = result(for: operation)?.message ?? "Not run"
            return "\(index + 1). [\(operation.kind.rawValue)]\n   Source: \(operation.source.path(percentEncoded: false))\n   Destination: \(destination)\n   Size: \(ByteCountFormatter.string(fromByteCount: operation.byteCount, countStyle: .file))\n   Reason: \(operation.explanation)\n   Result: \(result)"
        }
        let cleanupLines: [String]
        if let cleanupResult {
            let label = cleanupResult.removed ? "Removed empty folder" : "Would remove empty folder"
            cleanupLines = ["", "Empty-folder cleanup:"] + cleanupResult.folders.map { "- [\(label)] \($0.path(percentEncoded: false))" }
        } else {
            cleanupLines = []
        }
        return (header + lines + cleanupLines).joined(separator: "\n")
    }

    func copyOperationReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(operationReport, forType: .string)
        status = "Copied the detailed operation report to the clipboard."
    }

    private func resetAnalysis(keepStatus: Bool = false) {
        indexGeneration = UUID()
        workTask?.cancel()
        destinationIndexTask?.cancel()
        workTask = nil
        destinationIndexTask = nil
        destinationIndexResult = nil
        activity = .idle
        analysisIndex = nil
        report = nil
        plan = nil
        results = []
        cleanupResult = nil
        issues = []
        if !keepStatus {
            status = "Locations changed. Index the folders to continue."
        }
    }

    private func locationsAreValid(source: URL, target: URL) -> Bool {
        let sourcePath = source.standardizedFileURL.path(percentEncoded: false)
        let targetPath = target.standardizedFileURL.path(percentEncoded: false)
        return sourcePath != targetPath && !targetPath.hasPrefix(sourcePath + "/")
    }

    private func presetLimits(from index: AnalysisIndex) {
        maximumSourceFiles = index.sourceResult.records.count
        maximumSourceGigabytes = Self.gigabytesRoundingUp(index.sourceByteCount)
        maximumIndividualFileGigabytes = Self.gigabytesRoundingUp(index.largestSourceFileByteCount ?? 0)
    }

    private static func gigabytesRoundingUp(_ bytes: Int64) -> Int {
        guard bytes > 0 else { return 0 }
        return Int(bytes / 1_000_000_000 + (bytes % 1_000_000_000 == 0 ? 0 : 1))
    }

    private var currentLimits: AnalysisLimits {
        AnalysisLimits(
            maximumSourceFiles: limitsSourceFiles ? max(0, maximumSourceFiles) : nil,
            maximumSourceBytes: limitsSourceSize ? Self.bytes(fromGigabytes: maximumSourceGigabytes) : nil,
            maximumIndividualSourceFileBytes: limitsIndividualFileSize
                ? Self.bytes(fromGigabytes: maximumIndividualFileGigabytes)
                : nil
        )
    }

    private static func bytes(fromGigabytes gigabytes: Int) -> Int64 {
        Int64(min(max(0, gigabytes), Int(Int64.max / 1_000_000_000))) * 1_000_000_000
    }

    private func chooseFolder(prompt: String, startingAt currentURL: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = prompt
        panel.directoryURL = currentURL
        return panel.runModal() == .OK ? panel.url : nil
    }

    private static func saveBookmark(_ url: URL, named key: String) {
        guard let data = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func restoreBookmark(named key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) else { return nil }
        if stale { saveBookmark(url, named: key) }
        return url
    }

    private func completedSuccessfully(plan: OperationPlan, results: [OperationResult], dryRun: Bool) -> Bool {
        guard results.count == plan.operations.count else { return false }
        if dryRun { return true }
        return zip(plan.operations, results).allSatisfy { operation, result in
            result.performed || operation.kind == .skipExisting || operation.kind == .conflict
        }
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case duplicates = "Exact Duplicates"
    case plan = "Operation Plan"
    case issues = "Problems"

    var id: Self { self }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .duplicates: "doc.on.doc"
        case .plan: "list.bullet.clipboard"
        case .issues: "exclamationmark.triangle"
        }
    }
}

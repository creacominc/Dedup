import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class DedupAppModel {
    enum Activity: Equatable { case idle, scanning, executing }

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
    var dryRun = true
    var selectedSection: SidebarSection? = .overview

    private let engine = DeduplicationEngine()
    private let executor = OperationExecutor()
    private var workTask: Task<Void, Never>?

    init() {
        sourceURL = Self.restoreBookmark(named: "sourceBookmark")
        targetURL = Self.restoreBookmark(named: "targetBookmark")
    }

    func chooseSource() {
        guard let url = chooseFolder(prompt: "Select a source folder containing media") else { return }
        sourceURL = url
        Self.saveBookmark(url, named: "sourceBookmark")
        resetAnalysis()
    }

    func chooseTarget() {
        guard let url = chooseFolder(prompt: "Select /Volumes/VideoProjects/Originals") else { return }
        targetURL = url
        Self.saveBookmark(url, named: "targetBookmark")
        resetAnalysis()
    }

    func analyze() {
        guard let sourceURL, let targetURL, activity == .idle else { return }
        let sourcePath = sourceURL.standardizedFileURL.path(percentEncoded: false)
        let targetPath = targetURL.standardizedFileURL.path(percentEncoded: false)
        guard sourcePath != targetPath, !targetPath.hasPrefix(sourcePath + "/") else {
            status = "The target cannot be the source or a folder inside the source."
            return
        }
        report = nil
        plan = nil
        results = []
        issues = []
        activity = .scanning
        status = "Starting analysis…"

        workTask = Task { [weak self] in
            guard let self else { return }
            let sourceAccess = sourceURL.startAccessingSecurityScopedResource()
            let targetAccess = targetURL.startAccessingSecurityScopedResource()
            defer {
                if sourceAccess { sourceURL.stopAccessingSecurityScopedResource() }
                if targetAccess { targetURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let report = try await engine.analyze(source: sourceURL, target: targetURL) { progress in
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
                self.status = "Analysis complete: \(report.duplicateGroups.count) exact duplicate groups and \(report.uniqueSourceFiles.count) unique source files."
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
        activity = .executing
        status = dryRun ? "Running dry run…" : "Executing verified transfers…"
        results = []
        workTask = Task { [weak self] in
            guard let self else { return }
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
                self.activity = .idle
                self.workTask = nil
                return
            }
            let output = await executor.execute(plan: plan, dryRun: dryRun)
            self.results = output
            self.status = dryRun ? "Dry run complete; no files changed." : "Execution complete: \(output.count(where: \.performed)) verified transfers."
            self.activity = .idle
            self.workTask = nil
        }
    }

    func cancel() {
        workTask?.cancel()
        status = "Cancelling…"
    }

    func result(for operation: PlannedOperation) -> OperationResult? {
        results.first { $0.operation.id == operation.id }
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
            ""
        ]
        let lines = plan.operations.enumerated().map { index, operation in
            let destination = operation.destination?.path(percentEncoded: false) ?? "—"
            let result = result(for: operation)?.message ?? "Not run"
            return "\(index + 1). [\(operation.kind.rawValue)]\n   Source: \(operation.source.path(percentEncoded: false))\n   Destination: \(destination)\n   Size: \(ByteCountFormatter.string(fromByteCount: operation.byteCount, countStyle: .file))\n   Reason: \(operation.explanation)\n   Result: \(result)"
        }
        return (header + lines).joined(separator: "\n")
    }

    func copyOperationReport() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(operationReport, forType: .string)
        status = "Copied the detailed operation report to the clipboard."
    }

    private func resetAnalysis() {
        report = nil
        plan = nil
        results = []
        issues = []
        status = "Locations changed. Run analysis to create a new plan."
    }

    private func chooseFolder(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = prompt
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

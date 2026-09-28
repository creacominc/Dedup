import AppKit
import SwiftUI

struct ContentView: View {
    @State private var model = DedupAppModel()

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $model.selectedSection) { section in
                Label(section.rawValue, systemImage: section.symbol).tag(section)
            }
            .navigationTitle("Dedup")
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            VStack(spacing: 0) {
                locationHeader
                AnalysisLimitControls(model: model)
                Divider()
                sectionContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Divider()
                statusBar
            }
            .accessibilityIdentifier("dedup-main")
            .navigationTitle(model.selectedSection?.rawValue ?? "Dedup")
        }
        .frame(minWidth: 1_050, minHeight: 700)
    }

    private var locationHeader: some View {
        HStack(spacing: 16) {
            LocationButton(title: "Source", url: model.sourceURL, action: model.chooseSource)
            Image(systemName: "arrow.right").foregroundStyle(.secondary)
            LocationButton(title: "Originals", url: model.targetURL, action: model.chooseTarget)
            Spacer()
            if model.activity == .idle {
                Button(model.primaryActionTitle, systemImage: model.hasFolderIndex ? "number" : "folder.badge.gearshape", action: model.primaryAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("button-analyze")
                    .disabled(model.sourceURL == nil || model.targetURL == nil)
            } else {
                Button("Cancel", systemImage: "stop.fill", action: model.cancel)
            }
        }
        .padding()
    }

    @ViewBuilder private var sectionContent: some View {
        switch model.selectedSection ?? .overview {
        case .overview: OverviewView(report: model.report)
        case .duplicates: DuplicateResultsView(groups: model.report?.duplicateGroups ?? [])
        case .plan: OperationPlanView(model: model)
        case .issues: IssuesView(issues: model.issues)
        }
    }

    private var statusBar: some View {
        HStack {
            if model.activity != .idle {
                ProgressView()
                    .controlSize(.small)
                ProgressView(value: Double(model.progressCompleted), total: Double(max(model.progressTotal, 1)))
                    .frame(width: 180)
            }
            Text(model.status).font(.callout).foregroundStyle(.secondary).lineLimit(2)
            if let lastActivityAt = model.lastActivityAt, model.activity != .idle {
                Text(lastActivityAt, style: .timer)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
                    .help("Time since the most recent progress update")
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}

private struct LocationButton: View {
    let title: LocalizedStringKey
    let url: URL?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(url?.path(percentEncoded: false) ?? "Choose folder…").lineLimit(1).truncationMode(.middle)
            }
            .frame(maxWidth: 360, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }
}

private struct AnalysisLimitControls: View {
    @Bindable var model: DedupAppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let index = model.analysisIndex {
                HStack(spacing: 12) {
                    Text("Indexed source:")
                    Text(index.sourceResult.records.count, format: .number)
                    Text("files ·")
                    Text(index.sourceByteCount, format: .byteCount(style: .file))
                    Text("total ·")
                    Text(index.smallestSourceFileByteCount ?? 0, format: .byteCount(style: .file))
                    Text("to")
                    Text(index.largestSourceFileByteCount ?? 0, format: .byteCount(style: .file))
                    Text("per file")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Index the folders to discover file counts and sizes before setting pass limits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
            Text("Each pass")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("File limit", isOn: $model.limitsSourceFiles)
            TextField("Files", value: $model.maximumSourceFiles, format: .number)
                .frame(width: 80)
                .disabled(!model.limitsSourceFiles)
                .accessibilityLabel("Maximum source files per pass")
            Toggle("Data limit", isOn: $model.limitsSourceSize)
            TextField("GB", value: $model.maximumSourceGigabytes, format: .number)
                .frame(width: 80)
                .disabled(!model.limitsSourceSize)
                .accessibilityLabel("Maximum source gigabytes per pass")
            Text("GB total")
                .font(.caption)
                .foregroundStyle(.secondary)
            Toggle("Per-file limit", isOn: $model.limitsIndividualFileSize)
            TextField("GB", value: $model.maximumIndividualFileGigabytes, format: .number)
                .frame(width: 80)
                .disabled(!model.limitsIndividualFileSize)
                .accessibilityLabel("Maximum size of an individual source file in gigabytes")
            Text("GB each · largest eligible files first")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            }
            if let preview = model.limitPreview {
                Text("This pass includes \(preview.includedFiles) files (\(preview.includedBytes, format: .byteCount(style: .file))) and excludes \(preview.excludedFiles) files (\(preview.excludedBytes, format: .byteCount(style: .file))).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .textFieldStyle(.roundedBorder)
        .disabled(model.activity != .idle || !model.hasFolderIndex)
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
}

private struct OverviewView: View {
    let report: AnalysisReport?
    var body: some View {
        if let report {
            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 16) {
                metric("Source media in this pass", report.sourceFiles.count)
                metric("Source media discovered", report.discoveredSourceFileCount)
                metric("Source media excluded", report.excludedSourceFileCount)
                byteMetric("Data in this pass", report.selectedSourceByteCount)
                byteMetric("Data excluded", report.excludedSourceByteCount)
                metric("Target media", report.targetFiles.count)
                metric("Unique source files", report.uniqueSourceFiles.count)
                metric("Exact duplicate groups", report.duplicateGroups.count)
                metric("Problems", report.issues.count)
            }
            .padding(30)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ContentUnavailableView("No Analysis Yet", systemImage: "externaldrive", description: Text("Choose locations and analyze. Equal-size files are compared with progressively larger prefixes, followed by a complete hash only when needed."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func metric(_ title: LocalizedStringKey, _ value: Int) -> some View {
        GridRow { Text(title).foregroundStyle(.secondary); Text(value, format: .number).font(.title2.monospacedDigit()) }
    }
    private func byteMetric(_ title: LocalizedStringKey, _ value: Int64) -> some View {
        GridRow { Text(title).foregroundStyle(.secondary); Text(value, format: .byteCount(style: .file)).font(.title2.monospacedDigit()) }
    }
}

private struct DuplicateResultsView: View {
    let groups: [DuplicateGroupResult]
    var body: some View {
        if groups.isEmpty {
            ContentUnavailableView("No Exact Duplicates", systemImage: "doc.on.doc", description: Text("Only equal-size files with matching complete hashes appear here."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(groups) { group in
                DisclosureGroup {
                    ForEach(group.files) { file in LabeledContent(file.displayName, value: file.url.path(percentEncoded: false)) }
                } label: {
                    HStack {
                        Text("\(group.files.count) identical files")
                        Spacer()
                        Text(group.files.first?.byteCount ?? Int64.zero, format: .byteCount(style: .file))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct OperationPlanRow: Identifiable, Sendable {
    let id: UUID
    let action: String
    let source: String
    let sourceURL: URL
    let destination: String
    let destinationURL: URL?
    let duplicateURLs: [URL]
    let byteCount: Int64
    let reason: String
    let result: String
}

private struct FilePathMenu: View {
    let url: URL
    let securityScopedRoot: URL?
    let displayPath: String
    let relatedURLs: [URL]
    let relatedSecurityScopedRoots: [URL]
    let refreshToken: String
    @State private var fileExists = false
    @State private var existingRelatedURLs: Set<URL> = []

    var body: some View {
        Menu {
            Button("Open File", systemImage: "doc") {
                withSecurityScopedAccess(to: url, preferredRoot: securityScopedRoot) {
                    NSWorkspace.shared.open(url)
                }
            }
            .disabled(!fileExists)

            Button("Show in Finder", systemImage: "folder") {
                withSecurityScopedAccess(to: url, preferredRoot: securityScopedRoot) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
            .disabled(!fileExists)

            if let duplicateURL = relatedURLs.first, relatedURLs.count == 1 {
                Divider()
                Button("Open Duplicate", systemImage: "doc.on.doc") {
                    withSecurityScopedAccess(
                        to: duplicateURL,
                        preferredRoot: securityScopedRoot(for: duplicateURL)
                    ) {
                        NSWorkspace.shared.open(duplicateURL)
                    }
                }
                .disabled(!existingRelatedURLs.contains(duplicateURL))

                Button("Show Duplicate in Finder", systemImage: "folder") {
                    withSecurityScopedAccess(
                        to: duplicateURL,
                        preferredRoot: securityScopedRoot(for: duplicateURL)
                    ) {
                        NSWorkspace.shared.activateFileViewerSelecting([duplicateURL])
                    }
                }
                .disabled(!existingRelatedURLs.contains(duplicateURL))
            } else if relatedURLs.count > 1 {
                Divider()
                Menu("Exact Duplicates") {
                    ForEach(relatedURLs, id: \.self) { duplicateURL in
                        Menu(duplicateURL.lastPathComponent) {
                            Button("Open File", systemImage: "doc") {
                                withSecurityScopedAccess(
                                    to: duplicateURL,
                                    preferredRoot: securityScopedRoot(for: duplicateURL)
                                ) {
                                    NSWorkspace.shared.open(duplicateURL)
                                }
                            }
                            .disabled(!existingRelatedURLs.contains(duplicateURL))

                            Button("Show in Finder", systemImage: "folder") {
                                withSecurityScopedAccess(
                                    to: duplicateURL,
                                    preferredRoot: securityScopedRoot(for: duplicateURL)
                                ) {
                                    NSWorkspace.shared.activateFileViewerSelecting([duplicateURL])
                                }
                            }
                            .disabled(!existingRelatedURLs.contains(duplicateURL))
                        }
                    }
                }
            }
        } label: {
            Text(displayPath)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(fileExists ? "Click for file actions" : "This file does not currently exist")
        .onAppear(perform: refreshExistence)
        .onChange(of: refreshToken) {
            refreshExistence()
        }
    }

    private func refreshExistence() {
        withSecurityScopedAccess(to: url, preferredRoot: securityScopedRoot) {
            fileExists = FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
        }

        existingRelatedURLs = Set(relatedURLs.filter { relatedURL in
            var exists = false
            withSecurityScopedAccess(
                to: relatedURL,
                preferredRoot: securityScopedRoot(for: relatedURL)
            ) {
                exists = FileManager.default.fileExists(atPath: relatedURL.path(percentEncoded: false))
            }
            return exists
        })
    }

    private func securityScopedRoot(for fileURL: URL) -> URL? {
        relatedSecurityScopedRoots.first { root in
            let rootPath = root.standardizedFileURL.path(percentEncoded: false)
            let filePath = fileURL.standardizedFileURL.path(percentEncoded: false)
            return filePath == rootPath || filePath.hasPrefix(rootPath + "/")
        }
    }

    private func withSecurityScopedAccess(
        to fileURL: URL,
        preferredRoot: URL?,
        action: () -> Void
    ) {
        let accessURL = preferredRoot ?? fileURL
        let hasAccess = accessURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                accessURL.stopAccessingSecurityScopedResource()
            }
        }
        action()
    }
}

private struct OperationPlanComparator: SortComparator, Sendable {
    enum Field: Sendable {
        case action
        case source
        case destination
        case byteCount
        case reason
        case result
    }

    let field: Field
    var order: SortOrder = .forward

    func compare(_ lhs: OperationPlanRow, _ rhs: OperationPlanRow) -> ComparisonResult {
        let result: ComparisonResult
        switch field {
        case .action:
            result = lhs.action.localizedStandardCompare(rhs.action)
        case .source:
            result = lhs.source.localizedStandardCompare(rhs.source)
        case .destination:
            result = lhs.destination.localizedStandardCompare(rhs.destination)
        case .byteCount:
            result = lhs.byteCount == rhs.byteCount ? .orderedSame : (lhs.byteCount < rhs.byteCount ? .orderedAscending : .orderedDescending)
        case .reason:
            result = lhs.reason.localizedStandardCompare(rhs.reason)
        case .result:
            result = lhs.result.localizedStandardCompare(rhs.result)
        }

        guard order == .reverse else { return result }
        switch result {
        case .orderedAscending:
            return .orderedDescending
        case .orderedDescending:
            return .orderedAscending
        case .orderedSame:
            return .orderedSame
        }
    }
}

private struct OperationPlanView: View {
    @Bindable var model: DedupAppModel
    @State private var rows: [OperationPlanRow] = []
    @State private var sortOrder = [OperationPlanComparator(field: .source)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Dry run", isOn: $model.dryRun)
                    .disabled(model.activity != .idle)
                    .help("Report planned actions without changing files.")
                Toggle("Clean empty folders", isOn: $model.cleanEmptyFolders)
                    .disabled(model.activity != .idle)
                    .help("After successful processing, remove truly empty source subfolders from the leaves upward. The selected source folder is never removed.")
                Text(model.dryRun ? "No files will be changed" : "Verified transfers are enabled")
                    .foregroundStyle(model.dryRun ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                Spacer()
                Button("Copy Report", systemImage: "doc.on.doc", action: model.copyOperationReport)
                    .disabled(model.plan == nil)
                Button(model.dryRun ? "Run Dry Run" : "Execute Plan", systemImage: model.dryRun ? "play" : "externaldrive.badge.checkmark", action: model.executePlan)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.plan == nil || model.activity != .idle)
            }
            .padding()
            Divider()
            if model.plan != nil {
                Table(rows, sortOrder: $sortOrder) {
                    TableColumn("Action", sortUsing: OperationPlanComparator(field: .action)) { row in
                        Text(row.action)
                    }
                    .width(min: 120, ideal: 160, max: 220)
                    TableColumn("Source", sortUsing: OperationPlanComparator(field: .source)) { row in
                        FilePathMenu(
                            url: row.sourceURL,
                            securityScopedRoot: model.sourceURL,
                            displayPath: row.source,
                            relatedURLs: row.duplicateURLs,
                            relatedSecurityScopedRoots: [model.sourceURL, model.targetURL].compactMap { $0 },
                            refreshToken: row.result
                        )
                    }
                    .width(min: 280, ideal: 480, max: 700)
                    TableColumn("Destination", sortUsing: OperationPlanComparator(field: .destination)) { row in
                        if let destinationURL = row.destinationURL {
                            FilePathMenu(
                                url: destinationURL,
                                securityScopedRoot: model.targetURL,
                                displayPath: row.destination,
                                relatedURLs: [],
                                relatedSecurityScopedRoots: [],
                                refreshToken: row.result
                            )
                        } else {
                            Text(row.destination)
                        }
                    }
                    .width(min: 320, ideal: 580, max: 850)
                    TableColumn("Size", sortUsing: OperationPlanComparator(field: .byteCount)) { row in
                        Text(row.byteCount, format: .byteCount(style: .file))
                    }
                    .width(min: 80, ideal: 110, max: 140)
                    TableColumn("Reason", sortUsing: OperationPlanComparator(field: .reason)) { row in
                        Text(row.reason).lineLimit(2)
                    }
                    .width(min: 150, ideal: 220, max: 360)
                    TableColumn("Result", sortUsing: OperationPlanComparator(field: .result)) { row in
                        Text(row.result).lineLimit(2)
                    }
                    .width(min: 100, ideal: 140, max: 240)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("No Plan", systemImage: "list.bullet.clipboard", description: Text("Run analysis to generate a deterministic operation plan."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear(perform: refreshRows)
        .onChange(of: model.plan?.createdAt) {
            refreshRows()
        }
        .onChange(of: model.results.map(\.message)) {
            refreshRows()
        }
        .onChange(of: sortOrder) {
            rows.sort(using: sortOrder)
        }
    }

    private func refreshRows() {
        rows = (model.plan?.operations ?? []).map { operation in
            OperationPlanRow(
                id: operation.id,
                action: operation.kind.rawValue,
                source: operation.source.path(percentEncoded: false),
                sourceURL: operation.source,
                destination: operation.destination?.path(percentEncoded: false) ?? "—",
                destinationURL: operation.destination,
                duplicateURLs: duplicateURLs(for: operation),
                byteCount: operation.byteCount,
                reason: operation.explanation,
                result: model.result(for: operation)?.message ?? "Not run"
            )
        }
        rows.sort(using: sortOrder)
    }

    private func duplicateURLs(for operation: PlannedOperation) -> [URL] {
        guard let digest = operation.expectedDigest,
              let group = model.report?.duplicateGroups.first(where: { $0.digest == digest }) else {
            return []
        }
        let sourceURL = operation.source.standardizedFileURL
        return group.files
            .map(\.url)
            .filter { $0.standardizedFileURL != sourceURL }
            .sorted { $0.path(percentEncoded: false) < $1.path(percentEncoded: false) }
    }
}

private struct IssuesView: View {
    let issues: [ScanIssue]
    var body: some View {
        if issues.isEmpty {
            ContentUnavailableView("No Problems", systemImage: "checkmark.circle")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(issues) { issue in
                VStack(alignment: .leading) {
                    Text(issue.url.path(percentEncoded: false)).font(.headline)
                    Text(issue.message).foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview { ContentView() }

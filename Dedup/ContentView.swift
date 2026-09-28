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
                Divider()
                sectionContent
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
                Button("Analyze", systemImage: "magnifyingglass", action: model.analyze)
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

private struct OverviewView: View {
    let report: AnalysisReport?
    var body: some View {
        Group {
            if let report {
                Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 16) {
                    metric("Source media", report.sourceFiles.count)
                    metric("Target media", report.targetFiles.count)
                    metric("Unique source files", report.uniqueSourceFiles.count)
                    metric("Exact duplicate groups", report.duplicateGroups.count)
                    metric("Problems", report.issues.count)
                }.padding(30)
            } else {
                ContentUnavailableView("No Analysis Yet", systemImage: "externaldrive", description: Text("Choose locations and analyze. Equal-size files are compared with progressively larger prefixes, followed by a complete hash only when needed."))
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private func metric(_ title: LocalizedStringKey, _ value: Int) -> some View {
        GridRow { Text(title).foregroundStyle(.secondary); Text(value, format: .number).font(.title2.monospacedDigit()) }
    }
}

private struct DuplicateResultsView: View {
    let groups: [DuplicateGroupResult]
    var body: some View {
        if groups.isEmpty {
            ContentUnavailableView("No Exact Duplicates", systemImage: "doc.on.doc", description: Text("Only equal-size files with matching complete hashes appear here."))
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

private struct OperationPlanView: View {
    @Bindable var model: DedupAppModel
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Toggle("Dry run", isOn: $model.dryRun).help("Report planned actions without changing files.")
                Text(model.dryRun ? "No files will be changed" : "Verified transfers are enabled")
                    .foregroundStyle(model.dryRun ? AnyShapeStyle(.secondary) : AnyShapeStyle(.orange))
                Spacer()
                Button("Copy Report", systemImage: "doc.on.doc", action: model.copyOperationReport)
                    .disabled(model.plan == nil)
                Button(model.dryRun ? "Run Dry Run" : "Execute Plan", systemImage: model.dryRun ? "play" : "externaldrive.badge.checkmark", action: model.executePlan)
                    .buttonStyle(.borderedProminent)
                    .disabled(model.plan == nil || model.activity != .idle)
            }.padding()
            Divider()
            if let plan = model.plan {
                Table(plan.operations) {
                    TableColumn("Action") { Text($0.kind.rawValue) }.width(min: 140, ideal: 180)
                    TableColumn("Source") { Text($0.source.path(percentEncoded: false)).lineLimit(1) }
                    TableColumn("Destination") { Text($0.destination?.path(percentEncoded: false) ?? "—").lineLimit(1) }
                    TableColumn("Size") { Text($0.byteCount, format: .byteCount(style: .file)) }.width(100)
                    TableColumn("Reason") { Text($0.explanation).lineLimit(2) }.width(min: 180, ideal: 260)
                    TableColumn("Result") { operation in
                        Text(model.result(for: operation)?.message ?? "Not run")
                            .lineLimit(2)
                    }
                    .width(min: 150, ideal: 220)
                }
            } else {
                ContentUnavailableView("No Plan", systemImage: "list.bullet.clipboard", description: Text("Run analysis to generate a deterministic operation plan."))
            }
        }
    }
}

private struct IssuesView: View {
    let issues: [ScanIssue]
    var body: some View {
        if issues.isEmpty { ContentUnavailableView("No Problems", systemImage: "checkmark.circle") }
        else {
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

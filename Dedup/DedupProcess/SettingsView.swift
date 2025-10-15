import SwiftUI

struct SettingsView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedTab: Int
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Directory Selection")
                    .font(.headline)
                    .accessibilityIdentifier("label-directorySelection")
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source Directory")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(fileProcessor.sourceURL != nil ? "\(fileProcessor.sourceFiles.count) files found" : "Not selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("label-sourceDirectoryStatus")
                    }
                    Spacer()
                    Button("Select Source") {
                        Task {
                            await fileProcessor.selectSourceDirectory()
                        }
                    }
                    .accessibilityIdentifier("button-selectSource")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Target Directory")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(fileProcessor.targetURL != nil ? "\(fileProcessor.targetFiles.count) files found" : "Not selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("label-targetDirectoryStatus")
                    }
                    Spacer()
                    Button("Select Target") {
                        Task {
                            await fileProcessor.selectTargetDirectory()
                        }
                    }
                    .accessibilityIdentifier("button-selectTarget")
                }
            }
            Divider()
            // Always show status and button
            VStack(alignment: .leading, spacing: 12) {
                Text(statusText)
                    .font(.headline)
                    .accessibilityIdentifier(statusIdentifier)
                Button(buttonLabel) {
                    Task {
                        await fileProcessor.startProcessing()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!buttonEnabled)
                .accessibilityIdentifier(buttonIdentifier)
            }
            if let scanProgress = fileProcessor.scanProgress {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scanning...")
                        .font(.subheadline)
                        .accessibilityIdentifier("label-scanningStatus")
                    ProgressView(value: scanProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text(fileProcessor.currentOperation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("label-scanningOperation")
                }
            } else if fileProcessor.processingState == .processing {
                VStack(alignment: .leading, spacing: 8) {
                    Text(fileProcessor.currentOperation.contains("Scanning") ? "Scanning..." : "Processing files...")
                        .font(.subheadline)
                        .accessibilityIdentifier("label-processingStatus")
                    ProgressView(value: fileProcessor.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                    Text(fileProcessor.currentOperation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .accessibilityIdentifier("label-processingOperation")
                }
            }
            Spacer()
        }
        .padding()
    }
    
    private var statusText: String {
        switch fileProcessor.processingState {
        case .initial: return "Select Folders"
        case .ready: return "Ready to Process"
        case .processing: return "Processing"
        case .done: return "Done Processing"
        }
    }
    private var statusIdentifier: String {
        switch fileProcessor.processingState {
        case .initial: return "label-selectFolders"
        case .ready: return "label-readyToProcess"
        case .processing: return "label-processing"
        case .done: return "label-doneProcessing"
        }
    }
    private var buttonLabel: String {
        switch fileProcessor.processingState {
        case .processing: return "Processing..."
        default: return "Start Processing"
        }
    }
    private var buttonIdentifier: String {
        switch fileProcessor.processingState {
        case .processing: return "button-processing"
        default: return "button-startProcessing"
        }
    }
    private var buttonEnabled: Bool {
        fileProcessor.processingState == .ready || fileProcessor.processingState == .done
    }
}


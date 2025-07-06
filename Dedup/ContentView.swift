import SwiftUI

struct ContentView: View {
    @StateObject private var fileProcessor = FileProcessor()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                // Custom tab bar styled as segmented control
                HStack(spacing: 0) {
                    tabButton(title: "Files to Move", index: 0, systemImage: "folder.badge.plus", identifier: "tabButton-filesToMove")
                    tabButton(title: "Duplicates", index: 1, systemImage: "doc.on.doc", identifier: "tabButton-duplicates")
                    tabButton(title: "Settings", index: 2, systemImage: "gear", identifier: "tabButton-settings")
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .background(Color(NSColor.windowBackgroundColor))
                // Main content
                Group {
                    if selectedTab == 0 {
                        FilesToMoveView(fileProcessor: fileProcessor)
                    } else if selectedTab == 1 {
                        DuplicatesView(fileProcessor: fileProcessor)
                    } else {
                        SettingsView(fileProcessor: fileProcessor)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .navigationTitle("Dedup")
        .navigationSubtitle("Media File Deduplication Tool")
        .alert("Error", isPresented: .constant(fileProcessor.errorMessage != nil)) {
            Button("OK") {
                fileProcessor.errorMessage = nil
            }
        } message: {
            if let errorMessage = fileProcessor.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // Custom tab button styled as a segmented control
    @ViewBuilder
    private func tabButton(title: String, index: Int, systemImage: String, identifier: String) -> some View {
        Button(action: { selectedTab = index }) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(selectedTab == index ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(selectedTab == index ? Color.accentColor : Color.primary)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selectedTab == index ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: selectedTab == index ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityIdentifier(identifier)
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Dedup")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityIdentifier("app-title")
            
            Text("Media File Deduplication Tool")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .accessibilityIdentifier("app-subtitle")
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}

struct FilesToMoveView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @State private var selectedFiles: Set<FileInfo> = []
    @State private var selectAll = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Files to Move")
                    .font(.headline)
                Spacer()
                Button("Select All") {
                    if selectAll {
                        selectedFiles.removeAll()
                        selectAll = false
                    } else {
                        selectedFiles = Set(fileProcessor.filesToMove)
                        selectAll = true
                    }
                }
                .disabled(fileProcessor.filesToMove.isEmpty)
                .accessibilityIdentifier("button-selectAllFiles")
                Button("Move Selected") {
                    Task {
                        await fileProcessor.moveSelectedFiles(Array(selectedFiles))
                        selectedFiles.removeAll()
                        selectAll = false
                    }
                }
                .disabled(selectedFiles.isEmpty)
                .accessibilityIdentifier("button-moveSelectedFiles")
            }
            if fileProcessor.filesToMove.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No files to move")
                        .font(.headline)
                        .accessibilityIdentifier("label-noFilesToMove")
                    Text("Select source and target directories, then start processing to see files that can be moved.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(fileProcessor.filesToMove, id: \.id) { file in
                    HStack {
                        Button(action: {
                            if selectedFiles.contains(file) {
                                selectedFiles.remove(file)
                            } else {
                                selectedFiles.insert(file)
                            }
                        }) {
                            Image(systemName: selectedFiles.contains(file) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedFiles.contains(file) ? .accentColor : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("checkbox-file-\(file.id)")
                        
                        FileRowView(file: file)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .padding()
    }
}

struct DuplicatesView: View {
    @ObservedObject var fileProcessor: FileProcessor
    @State private var selectedDuplicates: Set<FileInfo> = []
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Duplicate Groups")
                    .font(.headline)
                
                Spacer()
                
                Button("Delete Selected") {
                    Task {
                        await fileProcessor.deleteSelectedDuplicates(Array(selectedDuplicates))
                        selectedDuplicates.removeAll()
                    }
                }
                .disabled(selectedDuplicates.isEmpty)
                .accessibilityIdentifier("button-deleteSelected")
            }
            
            if fileProcessor.duplicateGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No duplicates found")
                        .font(.headline)
                        .accessibilityIdentifier("label-noDuplicates")
                    
                    Text("Select source and target directories, then start processing to see duplicate files.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(fileProcessor.duplicateGroups.enumerated()), id: \.offset) { index, group in
                        Section(header: Text("Group \(index + 1) (\(group.count) files)")) {
                            ForEach(group, id: \.id) { file in
                                FileRowView(file: file)
                                    .onTapGesture {
                                        if selectedDuplicates.contains(file) {
                                            selectedDuplicates.remove(file)
                                        } else {
                                            selectedDuplicates.insert(file)
                                        }
                                    }
                                    .background(selectedDuplicates.contains(file) ? Color.accentColor.opacity(0.2) : Color.clear)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
        .padding()
    }
}

struct SettingsView: View {
    @ObservedObject var fileProcessor: FileProcessor
    
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
            
            // Only show Processing section when processing is actually running
            if fileProcessor.isProcessing {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Processing")
                        .font(.headline)
                        .accessibilityIdentifier("label-processingHeader")
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Processing files...")
                            .font(.subheadline)
                            .accessibilityIdentifier("label-processingStatus")
                        ProgressView(value: fileProcessor.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        Text(fileProcessor.currentOperation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityIdentifier("label-processingOperation")
                    }
                }
            }
            
            // Show Start Processing button when both directories are selected but not processing
            if fileProcessor.sourceURL != nil && fileProcessor.targetURL != nil && !fileProcessor.isProcessing {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ready to Process")
                        .font(.headline)
                        .accessibilityIdentifier("label-readyToProcess")
                    
                    Button("Start Processing") {
                        Task {
                            await fileProcessor.startProcessing()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("button-startProcessing")
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct FileRowView: View {
    let file: FileInfo
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(file.mediaType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(mediaTypeColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(file.formattedCreationDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch file.mediaType {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        }
    }
    
    private var iconColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        }
    }
    
    private var mediaTypeColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        }
    }
}

#Preview {
    ContentView()
} 
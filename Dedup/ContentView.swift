import SwiftUI

struct ContentView: View {
    @StateObject private var fileProcessor = FileProcessor()
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Main content
                TabView(selection: $selectedTab) {
                    FilesToMoveView(fileProcessor: fileProcessor)
                        .tabItem {
                            Label("Files to Move", systemImage: "folder.badge.plus")
                        }
                        .tag(0)
                        .accessibilityIdentifier("tab-filesToMove")
                    
                    DuplicatesView(fileProcessor: fileProcessor)
                        .tabItem {
                            Label("Duplicates", systemImage: "doc.on.doc")
                        }
                        .tag(1)
                        .accessibilityIdentifier("tab-duplicates")
                    
                    SettingsView(fileProcessor: fileProcessor)
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                        .tag(2)
                        .accessibilityIdentifier("tab-settings")
                }
            }
        }
        .navigationTitle("Dedup")
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
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dedup")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Media File Deduplication Tool")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if fileProcessor.isProcessing {
                    ProgressView(value: fileProcessor.progress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(width: 200)
                    
                    Text(fileProcessor.currentOperation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if fileProcessor.isProcessing {
                ProgressView(value: fileProcessor.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
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
                .accessibilityIdentifier("button-selectAll")
                
                Button("Move Selected") {
                    Task {
                        await fileProcessor.moveSelectedFiles(Array(selectedFiles))
                        selectedFiles.removeAll()
                        selectAll = false
                    }
                }
                .disabled(selectedFiles.isEmpty)
                .accessibilityIdentifier("button-moveSelected")
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
                List(fileProcessor.filesToMove, id: \.id, selection: $selectedFiles) { file in
                    FileRowView(file: file)
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
            
            // Only show Processing section when processing has started or both directories are selected
            if fileProcessor.isProcessing || (fileProcessor.sourceURL != nil && fileProcessor.targetURL != nil) {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Processing")
                        .font(.headline)
                        .accessibilityIdentifier("label-processingHeader")
                    
                    Button("Start Processing") {
                        Task {
                            await fileProcessor.startProcessing()
                        }
                    }
                    .disabled(fileProcessor.sourceURL == nil || fileProcessor.targetURL == nil || fileProcessor.isProcessing)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("button-startProcessing")
                    
                    if fileProcessor.isProcessing {
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
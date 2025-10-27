import SwiftUI
import AVKit

// Struct to represent a group of duplicate files with the same checksum
struct DuplicateGroup: Identifiable, Hashable {
    let id = UUID()
    let checksum: String
    let files: [MediaFile]
    let size: Int
    
    static func == (lhs: DuplicateGroup, rhs: DuplicateGroup) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct DuplicatesListView: View
{
    // [out] statusMsg - update with status
    @Binding var statusMsg: String
    @Binding var mergedFileSetBySize : FileSetBySize
    @Binding var targetURL: URL?
    @Binding var processed: Bool

    @State private var selectedGroup: DuplicateGroup?
    @State private var selectedGroups: Set<DuplicateGroup> = []
    
    // MEMORY FIX: Cache computed duplicate groups to avoid recreating on every render
    @State private var cachedDuplicateGroups: [DuplicateGroup] = []
    @State private var lastProcessedDate: Date = .distantPast
    @State private var needsRecomputation: Bool = true
    @State private var isProcessing: Bool = false
    @State private var hasProcessed: Bool = false
    
    // State for media player
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?
    
    private let fileManager = FileManager.default
    private let calendar = Calendar.current
    
    // MEMORY FIX: Computed property to group duplicates by their final (largest) checksum
    // Now uses cached result to avoid recreating arrays on every render
    private var duplicateGroups: [DuplicateGroup]
    {
        // Simply return cached result - recomputation is triggered by onChange handlers
        return cachedDuplicateGroups
    }
    
    // MEMORY FIX: Separate function to recompute duplicate groups only when needed
    private func recomputeDuplicateGroups()
    {
        print("DuplicatesListView: Recomputing duplicate groups...")
        print("DuplicatesListView: mergedFileSetBySize.totalFileCount = \(mergedFileSetBySize.totalFileCount)")
        print("DuplicatesListView: mergedFileSetBySize.lastProcessed = \(mergedFileSetBySize.lastProcessed)")

        // Group files by their checksum signature
        var groups: [String: [MediaFile]] = [:]
        var totalFiles = 0
        var uniqueFiles = 0
        var duplicateFiles = 0

        // Iterate directly over fileSetsBySize to avoid creating duplicateFiles array
        mergedFileSetBySize.forEachFile { file in
            totalFiles += 1
            
            // Skip if the file is marked unique
            if file.isUnique {
                uniqueFiles += 1
                print("Duplicate skipped: file isUnique: \(file.displayName)")
                return
            }

            // Skip if the file has no checksums yet
            if file.checksums.isEmpty {
                print("Duplicate skipped: no checksums: \(file.displayName)")
                return
            }

            duplicateFiles += 1

            // Get the cumulative checksum signature (all chunks combined)
            let validChecksums = file.checksums.values.filter { !$0.isEmpty }
            guard !validChecksums.isEmpty else {
                print("Duplicate skipped: no valid checksums: \(file.displayName)")
                return
            }

            let checksumSignature = validChecksums.joined(separator: "|")
            print("DuplicatesListView: Processing file '\(file.fileUrl.lastPathComponent)' with checksum signature (first 64 chars): \(String(checksumSignature.prefix(64)))")
            
            groups[checksumSignature, default: []].append(file)
        }
        
        print("DuplicatesListView: Total files: \(totalFiles), Unique: \(uniqueFiles), Duplicates: \(duplicateFiles)")
        print("DuplicatesListView: Found \(groups.count) unique checksum groups")
        
        // Convert to DuplicateGroup array and filter groups with more than 1 file
        let duplicateGroups: [DuplicateGroup] = groups.compactMap { checksum, files in
            guard files.count > 1 else { 
                print("DuplicatesListView: Skipping group with only 1 file")
                return nil 
            }
            
            // All files should have the same size since they're duplicates
            let size = files.first?.fileSize ?? 0
            let group = DuplicateGroup(checksum: checksum, files: files, size: size)
            print("DuplicatesListView: Created group with \(group.files.count) files, size: \(size)")
            return group
        }
        
        print("DuplicatesListView: Created \(duplicateGroups.count) duplicate groups")
        
        // Sort by size, largest first
        cachedDuplicateGroups = duplicateGroups.sorted { $0.size > $1.size }
        print("DuplicatesListView: After sorting, cachedDuplicateGroups.count = \(cachedDuplicateGroups.count)")
        
        // Log details about the groups
        for (index, group) in cachedDuplicateGroups.prefix(3).enumerated() {
            print("DuplicatesListView: Group \(index + 1): \(group.files.count) files, size: \(group.size) bytes")
            for file in group.files {
                print("  - \(file.fileUrl.lastPathComponent) (isUnique: \(file.isUnique))")
            }
        }
        
        lastProcessedDate = mergedFileSetBySize.lastProcessed
        needsRecomputation = false
        
        // Schedule status update to run on main thread to avoid state updates during view update
        let finalMessage = "Found \(cachedDuplicateGroups.count) duplicate groups (\(duplicateFiles) files)"
        DispatchQueue.main.async {
            self.statusMsg = finalMessage
        }
    }
    
    // Computed property to check if all groups are selected
    private var allGroupsSelected: Bool {
        !duplicateGroups.isEmpty && selectedGroups.count == duplicateGroups.count
    }
    
    var body: some View
    {
        VStack(spacing: 16)
        {
            // Header with controls
            HStack
            {
                Text("Duplicate Groups")
                    .font(.headline)
                Spacer()
                Text("\(duplicateGroups.count) groups")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Button(allGroupsSelected ? "Deselect All" : "Select All")
                {
                    if allGroupsSelected
                    {
                        selectedGroups.removeAll()
                        DispatchQueue.main.async {
                            statusMsg = "Deselected all groups."
                        }
                    }
                    else
                    {
                        selectedGroups = Set(duplicateGroups)
                        let count = selectedGroups.count
                        DispatchQueue.main.async {
                            statusMsg = "Selected \(count) groups."
                        }
                    }
                }
                .disabled(duplicateGroups.isEmpty)
                .accessibilityIdentifier("button-selectAllGroups")
                
                Button(isProcessing ? "Processing..." : "Process \(selectedGroups.count) Groups")
                {
                    Task {
                        await processSelectedGroups()
                    }
                }
                .disabled(selectedGroups.isEmpty || isProcessing)
                .accessibilityIdentifier("button-processSelectedGroups")
            }
            .padding(.horizontal)
            .onAppear {
                // Only recompute if we have actually processed files and need recomputation
                print("DuplicatesListView: onAppear called")
                print("DuplicatesListView: mergedFileSetBySize.lastProcessed = \(mergedFileSetBySize.lastProcessed)")
                print("DuplicatesListView: lastProcessedDate = \(lastProcessedDate)")
                print("DuplicatesListView: mergedFileSetBySize.totalFileCount = \(mergedFileSetBySize.totalFileCount)")
                print("DuplicatesListView: hasProcessed = \(hasProcessed)")
                print("DuplicatesListView: needsRecomputation = \(needsRecomputation)")
                
                // Only recompute if we have actually processed files and need recomputation
                //if hasProcessed && mergedFileSetBySize.totalFileCount > 0 && needsRecomputation
                if processed
                {
                    print("DuplicatesListView: Triggering recomputation on appear")
                    recomputeDuplicateGroups()
                }
                print("DuplicatesListView: After onAppear, cachedDuplicateGroups.count = \(cachedDuplicateGroups.count)")
            }
            
            // Target URL display
            if let targetURL = targetURL {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.blue)
                    Text("Target: \(targetURL.path())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Button(action: {
                        NSWorkspace.shared.selectFile(
                            targetURL.path(),
                            inFileViewerRootedAtPath: targetURL.deletingLastPathComponent().path()
                        )
                    }) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .help("Show in Finder")
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
                .padding(.horizontal)
            }
            
            if duplicateGroups.isEmpty {
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
                NavigationSplitView
                {
                    // Left side: List of duplicate groups
                    List(duplicateGroups, id: \.id, selection: $selectedGroup)
                    { group in
                        HStack {
                            Button(action: {
                                if selectedGroups.contains(group) {
                                    selectedGroups.remove(group)
                                } else {
                                    selectedGroups.insert(group)
                                }
                            }) {
                                Image(systemName: selectedGroups.contains(group) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedGroups.contains(group) ? .accentColor : .secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("checkbox-group-\(group.id)")
                            
                            DuplicateGroupRowView(group: group)
                        }
                        .tag(group)
                    }
                    .listStyle(PlainListStyle())
                    .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
                }
                detail:
                {
                    // Right side: Square grid of files in selected group
                    if let group = selectedGroup {
                        DuplicateGroupDetailView(
                            group: group,
                            player: $player,
                            isPlaying: $isPlaying,
                            currentTime: $currentTime,
                            duration: $duration,
                            timer: $timer
                        )
                        .id(group.checksum)  // Force view refresh when group changes
                        .onChange(of: group.checksum) { oldValue, newValue in
                            // Reset player state when switching groups
                            player?.pause()
                            player = nil
                            isPlaying = false
                            currentTime = 0
                            duration = 0
                            timer?.invalidate()
                            timer = nil
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Select a duplicate group to preview")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .onChange( of: processed )
        { oldValue, newValue in
            print( "DuplicatesListView: onChange detected - processed changed from \(oldValue) to \(newValue)" )
            if newValue
            {
                recomputeDuplicateGroups()
            }
        }
//        .onChange(of: mergedFileSetBySize.lastProcessed) { oldValue, newValue in
//            print("DuplicatesListView: onChange detected - lastProcessed changed from \(oldValue) to \(newValue)")
//            // Only trigger recomputation if processing actually completed (not just started)
//            if newValue > oldValue && mergedFileSetBySize.totalFileCount > 0 {
//                print("DuplicatesListView: Processing completed, triggering recomputation")
//                hasProcessed = true
//                needsRecomputation = true
//                recomputeDuplicateGroups()
//            }
//        }
//        .onChange(of: mergedFileSetBySize.lastModified) { oldValue, newValue in
//            print("DuplicatesListView: onChange detected - lastModified changed from \(oldValue) to \(newValue)")
//            // Clear cached groups when file collection changes (folder selection)
//            print("DuplicatesListView: File collection changed, clearing cached groups")
//            cachedDuplicateGroups = []
//            hasProcessed = false
//            needsRecomputation = false
//            statusMsg = "Select folders and press Process to find duplicates"
//        }
    }
    
    private func getDestinationURL(for file: MediaFile) throws -> URL {
        guard let targetURL = targetURL else {
            throw NSError(domain: "DuplicatesListView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Target URL not set"])
        }
        
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: file.creationDate
        )
        
        let year = String(format: "%04d", components.year ?? 2000)
        let month = String(format: "%02d", components.month ?? 1)
        let day = String(format: "%02d", components.day ?? 1)
        
        let mediaTypeFolder = file.mediaType.displayName
        
        let destinationFolder = targetURL
            .appendingPathComponent(mediaTypeFolder)
            .appendingPathComponent(year)
            .appendingPathComponent(month)
            .appendingPathComponent(day)
        
        // Create directory structure if it doesn't exist
        try fileManager.createDirectory(
            at: destinationFolder,
            withIntermediateDirectories: true
        )
        
        return destinationFolder.appendingPathComponent(file.displayName)
    }
    
    private func processSelectedGroups() async
    {
        guard !selectedGroups.isEmpty, let targetURL = targetURL else { return }

        DispatchQueue.main.async
        {
            self.isProcessing = true
            statusMsg = "Processing \(selectedGroups.count) duplicate groups..."
        }

        var processedCount = 0
        var totalFilesDeleted = 0
        var totalFilesMoved = 0

        // Convert to array for stable iteration
        let groupsToProcess = Array(selectedGroups)

        for group in groupsToProcess
        {
            do
            {
                // Check if any file in the group is already in the target folder
                let filesInTarget = group.files.filter
                { file in
                    file.fileUrl.path().hasPrefix(targetURL.path())
                }

                var fileToKeep: MediaFile?
                var filesToDelete: [MediaFile] = []

                if filesInTarget.isEmpty
                {
                    // No files in target, move the first one
                    fileToKeep = group.files.first
                    filesToDelete = Array(group.files.dropFirst())

                    if let fileToMove = fileToKeep
                    {
                        // Get the proper destination URL with date-based directory structure
                        let destinationURL = try getDestinationURL(for: fileToMove)

                        // Handle file name collision
                        var finalDestinationURL = destinationURL
                        if fileManager.fileExists(atPath: destinationURL.path())
                        {
                            let filename = destinationURL.deletingPathExtension().lastPathComponent
                            let fileExtension = destinationURL.pathExtension
                            let destinationFolder = destinationURL.deletingLastPathComponent()
                            var counter = 1

                            while fileManager.fileExists(atPath: finalDestinationURL.path())
                            {
                                let newFilename = "\(filename)_\(counter).\(fileExtension)"
                                finalDestinationURL = destinationFolder.appendingPathComponent(newFilename)
                                counter += 1
                            }
                        }

                        try fileManager.moveItem(at: fileToMove.fileUrl, to: finalDestinationURL)
                        totalFilesMoved += 1
                    }
                } // filesInTarget.isEmpty
                else
                {
                    // At least one file already in target, keep it and delete all others
                    fileToKeep = filesInTarget.first
                    filesToDelete = group.files.filter { $0.id != fileToKeep?.id }
                }

                // Delete all other files
                for file in filesToDelete
                {
                    try fileManager.removeItem(at: file.fileUrl)
                    totalFilesDeleted += 1
                    // Remove from mergedFileSetBySize
                    mergedFileSetBySize.remove(mediaFile: file)
                }

                // Remove the kept file from mergedFileSetBySize if it was moved
                if let kept = fileToKeep, filesInTarget.isEmpty
                {
                    mergedFileSetBySize.remove(mediaFile: kept)
                }

                processedCount += 1

                // Update status periodically
                if processedCount % 5 == 0
                {
                    let message = "Processed \(processedCount) of \(groupsToProcess.count) groups..."
                    DispatchQueue.main.async
                    {
                        statusMsg = message
                    }
                }

            }
            catch
            {
                let errorMessage = "Error processing group: \(error.localizedDescription)"
                DispatchQueue.main.async
                {
                    statusMsg = errorMessage
                }
                return
            }
        }

        // Clear selections
        selectedGroups.removeAll()
        selectedGroup = nil

        let finalMessage = "Processed \(processedCount) groups: moved \(totalFilesMoved) files, deleted \(totalFilesDeleted) files."
        DispatchQueue.main.async
        {
            self.isProcessing = false
            self.statusMsg = finalMessage
            // Trigger recomputation after processing is complete
            self.needsRecomputation = true
            self.recomputeDuplicateGroups()
        }
    }
}

// MARK: - Duplicate Group Row View
struct DuplicateGroupRowView: View
{
    let group: DuplicateGroup

    var body: some View
    {
        HStack(spacing: 12)
        {
            // Icon based on media type
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4)
            {
                Text("\(group.files.count) duplicate files")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Size: \(formatFileSize(group.size))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let firstFile = group.files.first
                {
                    HStack(spacing: 8)
                    {
                        Text(firstFile.mediaType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(iconColor.opacity(0.2))
                            .cornerRadius(4)

                        Text(firstFile.fileExtension.uppercased())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var iconName: String
    {
        guard let firstFile = group.files.first else { return "doc" }
        switch firstFile.mediaType {
        case .photo: return "photo.stack"
        case .video: return "play.rectangle.on.rectangle"
        case .audio: return "music.note.list"
        case .unsupported: return "doc.on.doc"
        }
    }
    
    private var iconColor: Color
    {
        guard let firstFile = group.files.first else { return .gray }
        switch firstFile.mediaType {
        case .photo: return .blue
        case .video: return .red
        case .audio: return .green
        case .unsupported: return .orange
        }
    }
    
    private func formatFileSize(_ size: Int) -> String
    {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Duplicate Group Detail View (Square Grid)
struct DuplicateGroupDetailView: View {
    let group: DuplicateGroup
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var timer: Timer?
    
    @State private var selectedFileForPreview: MediaFile?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with group info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duplicate Group")
                        .font(.headline)
                    Text("\(group.files.count) files • Size: \(formatFileSize(group.size))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Square grid of files
            ScrollView {
                let gridSize = calculateGridSize(fileCount: group.files.count)
                let totalCells = gridSize * gridSize
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: gridSize), spacing: 8) {
                    ForEach(0..<totalCells, id: \.self) { index in
                        if index < group.files.count {
                            // Show actual file
                            MediaFileThumbnailView(
                                file: group.files[index],
                                player: $player,
                                isPlaying: $isPlaying,
                                currentTime: $currentTime,
                                duration: $duration,
                                timer: $timer
                            )
                            .aspectRatio(1, contentMode: .fit)
                        } else {
                            // Show empty placeholder
                            Rectangle()
                                .fill(Color.black.opacity(0.1))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    Text("—")
                                        .font(.title)
                                        .foregroundColor(.secondary)
                                )
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    // Calculate grid size (e.g., 2x2, 3x3, 4x4, etc.)
    private func calculateGridSize(fileCount: Int) -> Int {
        let sqrtCount = sqrt(Double(fileCount))
        return max(2, Int(ceil(sqrtCount)))
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Media File Thumbnail View
struct MediaFileThumbnailView: View {
    let file: MediaFile
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var timer: Timer?
    
    @State private var showingDetail = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Media preview
            GeometryReader { geometry in
                MediaFileTypeView(
                    file: file,
                    player: $player,
                    isPlaying: $isPlaying,
                    currentTime: $currentTime,
                    duration: $duration,
                    timer: $timer
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
            }
            .aspectRatio(1, contentMode: .fill)
            .background(Color.black)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            
            // File info overlay
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileUrl.path())
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .padding(4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
            .padding(4)
        }
        .onTapGesture {
            showingDetail.toggle()
        }
        .popover(isPresented: $showingDetail) {
            VStack(alignment: .leading, spacing: 8) {
                Text(file.displayName)
                    .font(.headline)
                
                Text("Path: \(file.fileUrl.path())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Size: \(formatFileSize(file.fileSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Type: \(file.mediaType.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Created: \(file.formattedCreationDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(
                        file.fileUrl.path(),
                        inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path()
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(width: 400)
        }
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Media File Type View (copied from FilesToMoveListView pattern)
private struct MediaFileTypeView: View {
    let file: MediaFile
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var timer: Timer?
    
    var body: some View {
        Group {
            switch file.mediaType {
            case .photo:
                PhotoTypeView(file: file)
            case .video:
                VideoTypeView(
                    file: file,
                    player: $player,
                    isPlaying: $isPlaying,
                    currentTime: $currentTime,
                    duration: $duration,
                    timer: $timer
                )
            case .audio:
                AudioView(
                    file: file,
                    player: $player,
                    isPlaying: $isPlaying,
                    currentTime: $currentTime,
                    duration: $duration,
                    timer: $timer
                )
            default:
                UnsupportedFileView(file: file)
            }
        }
    }
}

// MARK: - Photo Type View
private struct PhotoTypeView: View {
    let file: MediaFile
    
    var body: some View {
        Group {
            if isRAWPhoto(file.fileExtension) {
                RAWImageView(file: file)
            } else {
                PhotoView(file: file)
            }
        }
    }
    
    private func isRAWPhoto(_ extension: String) -> Bool {
        let rawExtensions: [String] = ["cr2", "cr3", "crw", "raw", "dng", "arw", "nef", "orf", "rw2", "rwz"]
        return rawExtensions.contains(`extension`.lowercased())
    }
}

// MARK: - Video Type View
private struct VideoTypeView: View {
    let file: MediaFile
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var timer: Timer?
    
    var body: some View {
        Group {
            if file.fileExtension.lowercased() == "braw" {
                BRAWVideoView(
                    file: file,
                    player: $player,
                    isPlaying: $isPlaying,
                    currentTime: $currentTime,
                    duration: $duration,
                    timer: $timer
                )
            } else {
                VideoView(
                    file: file,
                    player: $player,
                    isPlaying: $isPlaying,
                    currentTime: $currentTime,
                    duration: $duration,
                    timer: $timer
                )
            }
        }
    }
}

// MARK: - Preview
#if DEBUG
#Preview("with duplicates") {
    @Previewable @State var statusMsg: String = "Ready"
    @Previewable @State var mergedFileSetBySize: FileSetBySize = createPreviewFileSetWithDuplicates()
    @Previewable @State var targetURL: URL? = URL(fileURLWithPath: "/Users/test/Target")
    @Previewable @State var processed: Bool = false

    DuplicatesListView(
        statusMsg: $statusMsg,
        mergedFileSetBySize: $mergedFileSetBySize,
        targetURL: $targetURL,
        processed: $processed
    )
}

#Preview("no duplicates") {
    @Previewable @State var statusMsg: String = "Ready"
    @Previewable @State var mergedFileSetBySize = FileSetBySize()
    @Previewable @State var targetURL: URL? = URL(fileURLWithPath: "/Users/test/Target")
    @Previewable @State var processed: Bool = false

    DuplicatesListView(
        statusMsg: $statusMsg,
        mergedFileSetBySize: $mergedFileSetBySize,
        targetURL: $targetURL,
        processed: $processed
    )
}

private func createPreviewFileSetWithDuplicates() -> FileSetBySize {
    let fileSet = FileSetBySize()
    
    // Create mock duplicate files (same size, will get same checksum)
    let file1 = MediaFile.mock(
        path: "/Users/test/Photos/IMG_1234.jpg",
        size: 2_456_789,
        isUnique: false,
        fileExtension: "jpg",
        mediaType: .photo
    )
    file1.checksums[2_456_789] = "abc123checksum"
    
    let file2 = MediaFile.mock(
        path: "/Users/test/Backup/IMG_1234.jpg",
        size: 2_456_789,
        isUnique: false,
        fileExtension: "jpg",
        mediaType: .photo
    )
    file2.checksums[2_456_789] = "abc123checksum"
    
    let file3 = MediaFile.mock(
        path: "/Users/test/OldPhotos/IMG_1234.jpg",
        size: 2_456_789,
        isUnique: false,
        fileExtension: "jpg",
        mediaType: .photo
    )
    file3.checksums[2_456_789] = "abc123checksum"
    
    // Another group of duplicates
    let video1 = MediaFile.mock(
        path: "/Users/test/Videos/vacation.mov",
        size: 125_456_789,
        isUnique: false,
        fileExtension: "mov",
        mediaType: .video
    )
    video1.checksums[125_456_789] = "def456checksum"
    
    let video2 = MediaFile.mock(
        path: "/Users/test/Archive/vacation.mov",
        size: 125_456_789,
        isUnique: false,
        fileExtension: "mov",
        mediaType: .video
    )
    video2.checksums[125_456_789] = "def456checksum"
    
    let mockFiles: [MediaFile] = [file1, file2, file3, video1, video2]
    fileSet.append(contentsOf: mockFiles)
    
    return fileSet
}
#endif

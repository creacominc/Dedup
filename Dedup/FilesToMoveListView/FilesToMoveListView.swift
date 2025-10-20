import SwiftUI
import AVKit

struct FilesToMoveListView: View
{
    // [out] statusMsg - update with status
    @Binding var statusMsg: String
    @Binding var mergedFileSetBySize : FileSetBySize
    @Binding var targetURL: URL?
    @State var selectedFile: MediaFile? = nil
    
    @State private var selectedFiles: Set<MediaFile> = []
    @State private var selectAll: Bool = false
    @State private var progress: Double = 0.0
    private let fileManager: FileManager = FileManager.default
    private let calendar: Calendar = Calendar.current
    
    // State for media player
    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?

    var body: some View
    {

        VStack(spacing: 16)
        {
            HStack
            {
                Text("Files to Move")
                    .font(.headline)
                Spacer()
                Button("Select All")
                {
                    if selectAll
                    {
                        selectedFiles.removeAll()
                        selectAll = false
                    }
                    else
                    {
                        selectedFiles = Set( mergedFileSetBySize.uniqueFiles.map(\.self)
                        )
                        selectAll = true
                        statusMsg = "Selected \( selectedFiles.count ) files."
                    }
                }
                .disabled( mergedFileSetBySize.totalUniqueFileCount == 0 )
                .accessibilityIdentifier("button-selectAllFiles")
                Button("Move \( selectedFiles.count ) Files") {
                    Task {
                        await moveSelectedFiles(Array(selectedFiles)
                                                , mergedFileSetBySize : mergedFileSetBySize
                        )
                        selectedFiles.removeAll()
                        selectAll = false
                    }
                }
                .disabled( selectedFiles.count == 0 )
                .accessibilityIdentifier("button-moveSelectedFiles")
            }
            .padding(.horizontal)

            if mergedFileSetBySize.totalUniqueFileCount == 0
            {
                VStack(spacing: 12)
                {
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
            }
            else
            {
                // NavigationSplitView with list on left and detail on right
                NavigationSplitView
                {
                    // Left side: List of files
                    List( mergedFileSetBySize.uniqueFiles, id: \.id, selection: $selectedFile)
                    { file in
                        HStack
                        {
                            Button(action: {
                                if selectedFiles.contains(file)
                                {
                                    selectedFiles.remove(file)
                                }
                                else
                                {
                                    selectedFiles.insert(file)
                                }
                            })
                            {
                                Image(systemName: selectedFiles.contains(file) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(selectedFiles.contains(file) ? .accentColor : .secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityIdentifier("checkbox-file-\(file.id)")
                            
                            FileRowView(file: file)
                        }
                        .tag(file)
                    }
                    .listStyle(PlainListStyle())
                    .navigationSplitViewColumnWidth(min: 300, ideal: 400, max: 600)
                }
                detail:
                {
                    // Right side: Detail view of selected file
                    if let file = selectedFile
                    {
                        FileDetailViewContent(
                            file: file,
                            player: $player,
                            isPlaying: $isPlaying,
                            currentTime: $currentTime,
                            duration: $duration,
                            timer: $timer
                        )
                    }
                    else
                    {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("Select a file to preview")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                // Progress
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())

            } // there are files to move
        }
    }


    private func getDestinationURL( for file: MediaFile ) throws -> URL
    {
        guard let targetURL: URL = targetURL else {
            fatalError("Target URL not set")
        }

        let components: DateComponents = calendar.dateComponents(
            [.year, .month, .day]
            , from: file.creationDate
        )

        let year: String = String(format: "%04d", components.year ?? 2000)
        let month: String = String(format: "%02d", components.month ?? 1)
        let day: String = String(format: "%02d", components.day ?? 1)

        let mediaTypeFolder: String = file.mediaType.displayName

        let destinationFolder: URL = targetURL
            .appendingPathComponent(mediaTypeFolder)
            .appendingPathComponent(year)
            .appendingPathComponent(month)
            .appendingPathComponent(day)

        // Create directory structure if it doesn't exist
        try fileManager.createDirectory( at: destinationFolder
                                         , withIntermediateDirectories: true
        )

        return destinationFolder.appendingPathComponent(file.displayName)
    }

    private func moveFile(_ file: MediaFile, to destinationURL: URL) async throws
    {
        // Check if destination file already exists
        if fileManager.fileExists(atPath: destinationURL.path)
        {
            // Generate unique filename
            let filename = destinationURL.deletingPathExtension().lastPathComponent
            let fileExtension = destinationURL.pathExtension
            var counter = 1
            var newDestinationURL = destinationURL

            while fileManager.fileExists(atPath: newDestinationURL.path)
            {
                let newFilename = "\(filename)_\(counter).\(fileExtension)"
                newDestinationURL = destinationURL.deletingLastPathComponent().appendingPathComponent(newFilename)
                counter += 1
            }

            try fileManager.moveItem(at: file.fileUrl, to: newDestinationURL)
        } else {
            try fileManager.moveItem(at: file.fileUrl, to: destinationURL)
        }
    }



    private func moveSelectedFiles(_ selectedFiles: [MediaFile]
                                   , mergedFileSetBySize : FileSetBySize
        ) async
    {
        guard !selectedFiles.isEmpty else { return }
        statusMsg = "Moving selected files..."
        progress = 0.0

        let totalFiles = selectedFiles.count
        var movedCount = 0

        for file in selectedFiles
        {
            do
            {
                let targetPath = try getDestinationURL(for: file)
                try await moveFile(file, to: targetPath)
                movedCount += 1
                progress = Double(movedCount) / Double(totalFiles)
                // remove this file from the mergeFileSetBySeze collection
                mergedFileSetBySize.remove( mediaFile: file )
                // every 10th of the total files, update statusMsg
                if movedCount.isMultiple(of: 10)
                {
                    statusMsg = "Moved \(movedCount) of \(totalFiles) files..."
                }
            }
            catch
            {
                statusMsg = "Failed to move \(file.displayName): \(error.localizedDescription)"
                break
            }
        }
        statusMsg = "Moved \(movedCount) of \(totalFiles) files..."
        progress = 0.0
    }
        
    
    
}

// MARK: - File Detail View Content
struct FileDetailViewContent: View {
    let file: MediaFile
    @Binding var player: AVPlayer?
    @Binding var isPlaying: Bool
    @Binding var currentTime: Double
    @Binding var duration: Double
    @Binding var timer: Timer?
    
    var body: some View {
        MediaFileTypeView(
            file: file,
            player: $player,
            isPlaying: $isPlaying,
            currentTime: $currentTime,
            duration: $duration,
            timer: $timer
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Media File Type View
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


#Preview( "with files" )
{
    @Previewable @State var statusMsg: String = "Ready to move files"
    @Previewable @State var targetURL: URL? = URL(fileURLWithPath: "/Users/test/Target")
    @Previewable @State var mergedFileSetBySize: FileSetBySize = createPreviewFileSet()

    FilesToMoveListView(
        statusMsg: $statusMsg,
        mergedFileSetBySize: $mergedFileSetBySize,
        targetURL: $targetURL
    )
}

private func createPreviewFileSet() -> FileSetBySize {
    let fileSet = FileSetBySize()
    
    // Create mock files one at a time to avoid complex expressions
    let file1 = MediaFile.mock(
        path: "/Users/test/Photos/IMG_1234.jpg",
        size: 2_456_789,
        fileExtension: "jpg",
        mediaType: MediaType.photo
    )
    
    let file2 = MediaFile.mock(
        path: "/Users/test/Videos/vacation_2024.mov",
        size: 125_456_789,
        fileExtension: "mov",
        mediaType: MediaType.video
    )
    
    let file3 = MediaFile.mock(
        path: "/Users/test/Photos/RAW/DSC_5678.dng",
        size: 45_123_456,
        fileExtension: "dng",
        mediaType: MediaType.photo
    )
    
    let file4 = MediaFile.mock(
        path: "/Users/test/Videos/wedding.mp4",
        size: 89_234_567,
        fileExtension: "mp4",
        mediaType: MediaType.video
    )
    
    let file5 = MediaFile.mock(
        path: "/Users/test/Photos/BRAW/clip_001.braw",
        size: 234_567_890,
        fileExtension: "braw",
        mediaType: MediaType.video
    )
    
    let file6 = MediaFile.mock(
        path: "/Users/test/Photos/sunset.cr2",
        size: 28_901_234,
        fileExtension: "cr2",
        mediaType: MediaType.photo
    )
    
    let mockFiles: [MediaFile] = [file1, file2, file3, file4, file5, file6]
    fileSet.append(contentsOf: mockFiles)
    
    return fileSet
}


#Preview( "no files" )
{
    @Previewable @State var statusMsg: String = "Ready to move files"
    @Previewable @State var targetURL: URL? = URL(fileURLWithPath: "/Users/test/Target")
    @Previewable @State var mergedFileSetBySize: FileSetBySize = FileSetBySize()

    FilesToMoveListView(
        statusMsg: $statusMsg,
        mergedFileSetBySize: $mergedFileSetBySize,
        targetURL: $targetURL
    )
}



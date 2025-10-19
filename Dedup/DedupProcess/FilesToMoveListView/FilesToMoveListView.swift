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
                    }
                }
                .disabled( mergedFileSetBySize.totalUniqueFileCount == 0 )
                .accessibilityIdentifier("button-selectAllFiles")
                Button("Move Selected") {
                    Task {
                        await moveSelectedFiles(Array(selectedFiles))
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



    private func moveSelectedFiles(_ selectedFiles: [MediaFile]) async
    {
        guard !selectedFiles.isEmpty else { return }

//        isProcessing = true
//        processingState = .processing
//        currentOperation = "Moving selected files..."
//        progress = 0.0

        let _ = selectedFiles.count
        var movedCount = 0

        for file in selectedFiles
        {
            do
            {
                let targetPath = try getDestinationURL(for: file)
                try await moveFile(file, to: targetPath)
                movedCount += 1
//                progress = Double(movedCount) / Double(totalFiles)
//                currentOperation = "Moved \(movedCount) of \(totalFiles) files..."
            }
            catch
            {
//                errorMessage = "Failed to move \(file.displayName): \(error.localizedDescription)"
                break
            }
        }

//        // Remove moved files from the filesToMove list
//        filesToMove.removeAll { file in
//            selectedFiles.contains { $0.id == file.id }
//        }
//
//        isProcessing = false
//        processingState = .done
//        currentOperation = ""
//        progress = 0.0
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
        let rawExtensions = ["cr2", "cr3", "crw", "raw", "dng", "arw", "nef", "orf", "rw2", "rwz"]
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
    @Previewable @State var mergedFileSetBySize: FileSetBySize = {
        let fileSet : FileSetBySize = FileSetBySize()
        
        // Create some sample mock files of different types
        let mockFiles : [MediaFile] = [
            MediaFile.mock(
                path: "/Users/test/Photos/IMG_1234.jpg",
                size: 2_456_789,
                fileExtension: "jpg",
                mediaType: .photo
            ),
            MediaFile.mock(
                path: "/Users/test/Videos/vacation_2024.mov",
                size: 125_456_789,
                fileExtension: "mov",
                mediaType: .video
            ),
            MediaFile.mock(
                path: "/Users/test/Photos/RAW/DSC_5678.dng",
                size: 45_123_456,
                fileExtension: "dng",
                mediaType: .photo
            ),
            MediaFile.mock(
                path: "/Users/test/Videos/wedding.mp4",
                size: 89_234_567,
                fileExtension: "mp4",
                mediaType: .video
            ),
            MediaFile.mock(
                path: "/Users/test/Photos/BRAW/clip_001.braw",
                size: 234_567_890,
                fileExtension: "braw",
                mediaType: .video
            ),
            MediaFile.mock(
                path: "/Users/test/Photos/sunset.cr2",
                size: 28_901_234,
                fileExtension: "cr2",
                mediaType: .photo
            )
        ]
        
        // Add all mock files to the set
        fileSet.append(contentsOf: mockFiles)
        
        return fileSet
    }()

    FilesToMoveListView(
        statusMsg: $statusMsg,
        mergedFileSetBySize: $mergedFileSetBySize,
        targetURL: $targetURL
    )
}


#Preview( "no files" )
{
    @Previewable @State var statusMsg: String = "Ready to move files"
    @Previewable @State var targetURL: URL? = URL(fileURLWithPath: "/Users/test/Target")
    @Previewable @State var mergedFileSetBySize: FileSetBySize = {
        let fileSet : FileSetBySize = FileSetBySize()

        // Create some sample mock files of different types
        let mockFiles : [MediaFile] = []

        // Add all mock files to the set
        fileSet.append(contentsOf: mockFiles)

        return fileSet
    }()

    FilesToMoveListView(
        statusMsg: $statusMsg,
        mergedFileSetBySize: $mergedFileSetBySize,
        targetURL: $targetURL
    )
}



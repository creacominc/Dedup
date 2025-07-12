import Foundation
import CryptoKit
import AppKit

/// Processing state for the application
enum ProcessingState {
    case initial
    case ready
    case processing
    case done
}

/// Main processor for handling file deduplication and organization
@MainActor
class FileProcessor: ObservableObject {
    @Published var sourceFiles: [FileInfo] = []
    @Published var targetFiles: [FileInfo] = []
    @Published var filesToMove: [FileInfo] = []
    @Published var duplicateGroups: [[FileInfo]] = []
    @Published var isProcessing = false
    @Published var progress: Double = 0.0
    @Published var currentOperation = ""
    @Published var errorMessage: String?
    @Published var processingState: ProcessingState = .initial
    
    var sourceURL: URL?
    var targetURL: URL?
    private var checksumCache: [String: [FileInfo]] = [:]
    private let fileManager = FileManager.default
    
    // MARK: - Public Methods
    
    func selectSourceDirectory() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select source directory containing media files"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourceURL = url
            await scanSourceDirectory()
            updateProcessingState()
        }
    }
    
    func selectTargetDirectory() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select target directory for organized files"
        
        if panel.runModal() == .OK, let url = panel.url {
            targetURL = url
            await scanTargetDirectory()
            updateProcessingState()
        }
    }
    
    func startProcessing() async {
        guard let sourceURL = sourceURL, let targetURL = targetURL else {
            errorMessage = "Please select both source and target directories.  "
            return
        }
        print( "source: \(sourceURL), target: \(targetURL)" )
        isProcessing = true
        processingState = .processing
        progress = 0.0
        errorMessage = nil
        
        await processFiles()
        
        isProcessing = false
        processingState = .done
    }
    
    func moveSelectedFiles(_ selectedFiles: [FileInfo]) async {
        guard !selectedFiles.isEmpty else { return }
        
        isProcessing = true
        processingState = .processing
        currentOperation = "Moving selected files..."
        progress = 0.0
        
        let totalFiles = selectedFiles.count
        var movedCount = 0
        
        for file in selectedFiles {
            do {
                let targetPath = getTargetPath(for: file)
                try await moveFile(file, to: targetPath)
                movedCount += 1
                progress = Double(movedCount) / Double(totalFiles)
                currentOperation = "Moved \(movedCount) of \(totalFiles) files..."
            } catch {
                errorMessage = "Failed to move \(file.name): \(error.localizedDescription)"
                break
            }
        }
        
        // Remove moved files from the filesToMove list
        filesToMove.removeAll { file in
            selectedFiles.contains { $0.id == file.id }
        }
        
        isProcessing = false
        processingState = .done
        currentOperation = ""
        progress = 0.0
    }
    
    func deleteSelectedDuplicates(_ duplicates: [FileInfo]) async {
        isProcessing = true
        processingState = .processing
        
        for file in duplicates {
            do {
                try fileManager.removeItem(at: file.url)
            } catch {
                errorMessage = "Failed to delete \(file.displayName): \(error.localizedDescription)"
                isProcessing = false
                processingState = .ready
                return
            }
        }
        
        // Refresh the lists after deleting files
        await scanSourceDirectory()
        await scanTargetDirectory()
        
        isProcessing = false
        processingState = .done
    }
    
    // MARK: - Private Methods
    
    private func updateProcessingState() {
        if sourceURL == nil || targetURL == nil {
            processingState = .initial
        } else if processingState == .done {
            // If we're done but directories changed, go back to ready
            processingState = .ready
        } else if processingState == .initial {
            processingState = .ready
        }
    }
    
    private func scanSourceDirectory() async {
        guard let sourceURL = sourceURL else { return }
        
        currentOperation = "Scanning source directory..."
        progress = 0.0
        
        do {
            let files = try await scanDirectory(sourceURL)
            sourceFiles = files
            progress = 0.3
        } catch {
            errorMessage = "Failed to scan source directory: \(error.localizedDescription)"
        }
    }
    
    private func scanTargetDirectory() async {
        guard let targetURL = targetURL else { return }
        
        currentOperation = "Scanning target directory..."
        progress = 0.3
        
        do {
            let files = try await scanDirectory(targetURL)
            targetFiles = files
            progress = 0.6
            
            // Build checksum cache for target files
            await buildChecksumCache()
            progress = 0.8
        } catch {
            errorMessage = "Failed to scan target directory: \(error.localizedDescription)"
        }
    }
    
    private func scanDirectory(_ url: URL) async throws -> [FileInfo] {
        var files: [FileInfo] = []
        
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: nil)
        
        while let fileURL = enumerator?.nextObject() as? URL {
            // Skip symbolic links and mounted partitions
            let resourceValues = try fileURL.resourceValues(forKeys: [.isSymbolicLinkKey])
            
            if resourceValues.isSymbolicLink == true {
                continue
            }
            
            // Only process media files
            if isMediaFile(fileURL) {
                do {
                    var fileInfo = try FileInfo(url: fileURL)
                    // Extract metadata for the file
                    await fileInfo.extractMetadata()
                    files.append(fileInfo)
                } catch {
                    print("Failed to process file \(fileURL.path): \(error)")
                }
            }
        }
        
        return files
    }
    
    func isMediaFile(_ url: URL) -> Bool {
        let mediaExtensions = [
            // Photos
            "cr2", "rw2", "raw", "tiff", "tif", "jpeg", "jpg", "png", "psd", "bmp", "dng",
            // Videos
            "braw", "mov", "mp4", "avi", "mkv", "wmv", "flv", "webm",
            // Audio
            "wav", "flac", "aac", "m4a", "mp3", "ogg"
        ]
        
        let fileExtension = url.pathExtension.lowercased()
        return mediaExtensions.contains(fileExtension)
    }
    
    private func buildChecksumCache() async {
        currentOperation = "Building checksum cache..."
        
        for file in targetFiles {
            do {
                var mutableFile = file
                try await mutableFile.computeChecksums()
                
                // Store in cache by checksum
                if let checksum = mutableFile.checksumFull {
                    if checksumCache[checksum] == nil {
                        checksumCache[checksum] = []
                    }
                    checksumCache[checksum]?.append(mutableFile)
                }
            } catch {
                print("Failed to compute checksums for \(file.displayName): \(error)")
            }
        }
    }
    
    private func processFiles() async {
        currentOperation = "Processing files for duplicates..."
        
        var filesToMove: [FileInfo] = []
        var duplicateGroups: [[FileInfo]] = []
        
        // Group files by size first for efficiency
        let sizeGroups = Dictionary(grouping: sourceFiles) { $0.size }
        
        for (_, files) in sizeGroups {
            if files.count == 1 {
                // Single file of this size - check if it exists in target
                let file = files[0]
                let existsInTarget = await fileExistsInTarget(file)
                if !existsInTarget {
                    filesToMove.append(file)
                }
            } else {
                // Multiple files of same size - need to check for duplicates
                let duplicates = await findDuplicates(in: files)
                if duplicates.count > 1 {
                    duplicateGroups.append(duplicates)
                } else if duplicates.count == 1 {
                    let file = duplicates[0]
                    let existsInTarget = await fileExistsInTarget(file)
                    if !existsInTarget {
                        filesToMove.append(file)
                    }
                }
            }
        }
        
        self.filesToMove = filesToMove
        self.duplicateGroups = duplicateGroups
        progress = 1.0
        currentOperation = "Processing complete"
    }
    
    private func fileExistsInTarget(_ file: FileInfo) async -> Bool {
        // Check by name similarity first
        for targetFile in targetFiles {
            if file.isLikelyDuplicate(of: targetFile) {
                return true
            }
        }
        
        // Check by checksum
        if let checksum = file.checksumFull {
            return checksumCache[checksum]?.isEmpty == false
        }
        
        return false
    }
    
    private func findDuplicates(in files: [FileInfo]) async -> [FileInfo] {
        var duplicates: [FileInfo] = []
        
        for file in files {
            var isDuplicate = false
            
            // Check against target files
            for targetFile in targetFiles {
                if file.isDefinitelyDuplicate(of: targetFile) {
                    isDuplicate = true
                    break
                }
            }
            
            // Check against other source files
            for otherFile in files {
                if file != otherFile && file.isDefinitelyDuplicate(of: otherFile) {
                    isDuplicate = true
                    break
                }
            }
            
            if !isDuplicate {
                duplicates.append(file)
            }
        }
        
        // Sort by quality preference
        return duplicates.sorted { $0.isHigherQuality(than: $1) }
    }
    
    private func getDestinationURL(for file: FileInfo, in targetURL: URL) throws -> URL {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: file.creationDate)
        
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
        try fileManager.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        
        return destinationFolder.appendingPathComponent(file.displayName)
    }
    
    private func getTargetPath(for file: FileInfo) -> URL {
        guard let targetURL = targetURL else {
            fatalError("Target URL not set")
        }
        
        do {
            return try getDestinationURL(for: file, in: targetURL)
        } catch {
            fatalError("Failed to get target path: \(error)")
        }
    }
    
    private func moveFile(_ file: FileInfo, to destinationURL: URL) async throws {
        // Check if destination file already exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            // Generate unique filename
            let filename = destinationURL.deletingPathExtension().lastPathComponent
            let fileExtension = destinationURL.pathExtension
            var counter = 1
            var newDestinationURL = destinationURL
            
            while fileManager.fileExists(atPath: newDestinationURL.path) {
                let newFilename = "\(filename)_\(counter).\(fileExtension)"
                newDestinationURL = destinationURL.deletingLastPathComponent().appendingPathComponent(newFilename)
                counter += 1
            }
            
            try fileManager.moveItem(at: file.url, to: newDestinationURL)
        } else {
            try fileManager.moveItem(at: file.url, to: destinationURL)
        }
    }
} 

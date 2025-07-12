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
    private let fileManager = FileManager.default
    
    // Statistics for efficiency tracking
    private var checksumsComputed = 0
    private var checksumsCached = 0
    private var comparisonsPerformed = 0
    
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
        print("🚀 [START] Starting processing...")
        print("🚀 [START] Source: \(sourceURL)")
        print("🚀 [START] Target: \(targetURL)")
        isProcessing = true
        processingState = .processing
        progress = 0.0
        errorMessage = nil
        
        let startTime = Date()
        await processFiles()
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        print("🚀 [START] Processing completed in \(String(format: "%.2f", duration)) seconds")
        printEfficiencyStatistics()
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
            progress = 0.8
            print("📁 [TARGET] Target directory scan complete: \(files.count) files")
        } catch {
            errorMessage = "Failed to scan target directory: \(error.localizedDescription)"
        }
    }
    
    private func scanDirectory(_ url: URL) async throws -> [FileInfo] {
        var files: [FileInfo] = []
        var processedCount = 0
        
        print("📁 [SCAN] Starting scan of directory: \(url.path)")
        
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
                    // Extract metadata for the file (this is still quick to gather)
                    await fileInfo.extractMetadata()
                    files.append(fileInfo)
                    processedCount += 1
                    
                    if processedCount % 100 == 0 {
                        print("📁 [SCAN] Processed \(processedCount) files...")
                    }
                } catch {
                    print("❌ [SCAN] Failed to process file \(fileURL.path): \(error)")
                }
            }
        }
        
        print("📁 [SCAN] Completed scan: found \(files.count) media files")
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
    
    // Removed buildChecksumCache() - checksums are now computed on-demand during comparison
    
    private func processFiles() async {
        currentOperation = "Processing files for duplicates..."
        print("🔄 [PROCESS] Starting file processing...")
        
        var filesToMove: [FileInfo] = []
        var duplicateGroups: [[FileInfo]] = []
        
        // First, check each source file against target files for duplicates
        print("🔄 [PROCESS] Checking source files against target files for duplicates...")
        for sourceFile in sourceFiles {
            print("🔄 [PROCESS] Checking source file: \(sourceFile.displayName)")
            let targetDuplicates = await findTargetDuplicates(for: sourceFile)
            if !targetDuplicates.isEmpty {
                // Create a duplicate group with only the source file
                // Target duplicates will be shown in the view when source file is selected
                let group = [sourceFile]
                duplicateGroups.append(group)
                print("🔄 [PROCESS] Found source-target duplicate group: \(sourceFile.displayName) matches \(targetDuplicates.count) target files")
            }
        }
        
        // Group remaining files by size for source-only duplicates
        let filesNotInTarget = sourceFiles.filter { sourceFile in
            !duplicateGroups.flatMap { $0 }.contains { $0.id == sourceFile.id }
        }
        
        let sizeGroups = Dictionary(grouping: filesNotInTarget) { $0.size }
        print("🔄 [PROCESS] Grouped \(filesNotInTarget.count) remaining files into \(sizeGroups.count) size groups")
        
        var processedGroups = 0
        for (size, files) in sizeGroups {
            processedGroups += 1
            print("🔄 [PROCESS] Processing size group \(processedGroups)/\(sizeGroups.count): \(files.count) files of size \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
            
            if files.count == 1 {
                // Single file of this size - check if it exists in target
                let file = files[0]
                print("🔄 [PROCESS] Single file of size \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)): \(file.displayName)")
                let existsInTarget = await fileExistsInTarget(file)
                if !existsInTarget {
                    filesToMove.append(file)
                    print("🔄 [PROCESS] ✅ File will be moved: \(file.displayName)")
                } else {
                    print("🔄 [PROCESS] ❌ File exists in target: \(file.displayName)")
                }
            } else {
                // Multiple files of same size - need to check for duplicates
                print("🔄 [PROCESS] Multiple files of same size, checking for duplicates...")
                let duplicates = await findDuplicates(in: files)
                if duplicates.count > 1 {
                    duplicateGroups.append(duplicates)
                    print("🔄 [PROCESS] Found source-only duplicate group with \(duplicates.count) files")
                } else if duplicates.count == 1 {
                    let file = duplicates[0]
                    let existsInTarget = await fileExistsInTarget(file)
                    if !existsInTarget {
                        filesToMove.append(file)
                        print("🔄 [PROCESS] ✅ Best duplicate will be moved: \(file.displayName)")
                    } else {
                        print("🔄 [PROCESS] ❌ Best duplicate exists in target: \(file.displayName)")
                    }
                } else {
                    print("🔄 [PROCESS] No unique files found in this size group")
                }
            }
        }
        
        self.filesToMove = filesToMove
        self.duplicateGroups = duplicateGroups
        progress = 1.0
        currentOperation = "Processing complete"
        print("🔄 [PROCESS] Processing complete: \(filesToMove.count) files to move, \(duplicateGroups.count) duplicate groups")
    }
    
    private func fileExistsInTarget(_ file: FileInfo) async -> Bool {
        print("🔍 [TARGET] Checking if \(file.displayName) exists in target...")
        
        // Check by size and then efficient checksum comparison
        for targetFile in targetFiles {
            if file.size == targetFile.size {
                print("🔍 [TARGET] Size match found, comparing checksums: \(file.displayName) vs \(targetFile.displayName)")
                var mutableFile = file
                let isDuplicate = await mutableFile.isDefinitelyDuplicateEfficient(of: targetFile)
                if isDuplicate {
                    print("🔍 [TARGET] ✅ Found duplicate in target: \(file.displayName)")
                    return true
                }
            }
        }
        
        print("🔍 [TARGET] ❌ File not found in target: \(file.displayName)")
        return false
    }
    
    func findTargetDuplicates(for sourceFile: FileInfo) -> [FileInfo] {
        // Synchronous version for UI display
        // Return target files that match this source file
        var matches: [FileInfo] = []
        for targetFile in targetFiles {
            let nameMatch = targetFile.displayName == sourceFile.displayName
            let sizeMatch = targetFile.size == sourceFile.size
            if nameMatch && sizeMatch {
                matches.append(targetFile)
            }
        }
        return matches
    }
    
    private func findTargetDuplicates(for sourceFile: FileInfo) async -> [FileInfo] {
        var targetDuplicates: [FileInfo] = []
        print("🔍 [TARGET_DUP] Finding target duplicates for \(sourceFile.displayName)...")
        
        for targetFile in targetFiles {
            if sourceFile.size == targetFile.size {
                print("🔍 [TARGET_DUP] Size match found, comparing: \(sourceFile.displayName) vs \(targetFile.displayName)")
                var mutableSourceFile = sourceFile
                if await mutableSourceFile.isDefinitelyDuplicateEfficient(of: targetFile) {
                    targetDuplicates.append(targetFile)
                    print("🔍 [TARGET_DUP] ✅ Found target duplicate: \(targetFile.displayName)")
                } else {
                    print("🔍 [TARGET_DUP] ❌ Not a duplicate: \(targetFile.displayName)")
                }
            }
        }
        
        print("🔍 [TARGET_DUP] Found \(targetDuplicates.count) target duplicates for \(sourceFile.displayName)")
        return targetDuplicates
    }
    
    private func findDuplicates(in files: [FileInfo]) async -> [FileInfo] {
        var duplicates: [FileInfo] = []
        print("🔍 [DUPLICATES] Finding unique files among \(files.count) files of same size...")
        
        for (index, file) in files.enumerated() {
            print("🔍 [DUPLICATES] Checking file \(index + 1)/\(files.count): \(file.displayName)")
            var isDuplicate = false
            
            // Check against target files
            for targetFile in targetFiles {
                if file.size == targetFile.size {
                    var mutableFile = file
                    if await mutableFile.isDefinitelyDuplicateEfficient(of: targetFile) {
                        print("🔍 [DUPLICATES] ❌ File is duplicate of target: \(file.displayName)")
                        isDuplicate = true
                        break
                    }
                }
            }
            
            // Check against other source files (only if not already found to be duplicate)
            if !isDuplicate {
                for otherFile in files {
                    if file != otherFile && file.size == otherFile.size {
                        var mutableFile = file
                        if await mutableFile.isDefinitelyDuplicateEfficient(of: otherFile) {
                            print("🔍 [DUPLICATES] ❌ File is duplicate of other source file: \(file.displayName)")
                            isDuplicate = true
                            break
                        }
                    }
                }
            }
            
            if !isDuplicate {
                duplicates.append(file)
                print("🔍 [DUPLICATES] ✅ File is unique: \(file.displayName)")
            }
        }
        
        // Sort by quality preference
        let sortedDuplicates = duplicates.sorted { $0.isHigherQuality(than: $1) }
        print("🔍 [DUPLICATES] Found \(sortedDuplicates.count) unique files out of \(files.count) total")
        return sortedDuplicates
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
    
    private func printEfficiencyStatistics() {
        print("📊 [STATS] Efficiency Statistics:")
        print("📊 [STATS] - Total source files: \(sourceFiles.count)")
        print("📊 [STATS] - Total target files: \(targetFiles.count)")
        print("📊 [STATS] - Files to move: \(filesToMove.count)")
        print("📊 [STATS] - Duplicate groups found: \(duplicateGroups.count)")
        
        // Calculate total size processed
        let sourceSize = sourceFiles.reduce(0) { $0 + $1.size }
        let targetSize = targetFiles.reduce(0) { $0 + $1.size }
        print("📊 [STATS] - Total source size: \(ByteCountFormatter.string(fromByteCount: sourceSize, countStyle: .file))")
        print("📊 [STATS] - Total target size: \(ByteCountFormatter.string(fromByteCount: targetSize, countStyle: .file))")
        
        print("📊 [STATS] - Checksums computed on-demand only when needed for comparison")
        print("📊 [STATS] - No upfront checksum computation for target files")
        print("📊 [STATS] - Each checksum size computed at most once per file")
    }
} 

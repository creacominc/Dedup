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

/// Represents a group of duplicates: a source file and its matching target files
struct DuplicateGroup: Identifiable {
    let id = UUID()
    let source: FileInfo
    let targets: [FileInfo]
}

/// Main processor for handling file deduplication and organization
@MainActor
class FileProcessor: ObservableObject {
    @Published var sourceFiles: [FileInfo] = []
    @Published var targetFiles: [FileInfo] = []
    @Published var filesToMove: [FileInfo] = []
    @Published var duplicateGroups: [DuplicateGroup] = []
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
        var duplicateGroups: [DuplicateGroup] = []
        
        // First, check each source file against target files for duplicates
        print("🔄 [PROCESS] Checking source files against target files for duplicates...")
        for sourceFile in sourceFiles {
            print("🔄 [PROCESS] Checking source file: \(sourceFile.displayName)")
            let targetDuplicates = await findTargetDuplicates(for: sourceFile)
            if !targetDuplicates.isEmpty {
                // Store both the source file and its matching target files
                let group = DuplicateGroup(source: sourceFile, targets: targetDuplicates)
                duplicateGroups.append(group)
                print("🔄 [PROCESS] Found source-target duplicate group: \(sourceFile.displayName) matches \(targetDuplicates.count) target files")
            }
        }
        
        // Group remaining files by size for source-only duplicates
        let filesNotInTarget = sourceFiles.filter { sourceFile in
            !duplicateGroups.contains { $0.source.id == sourceFile.id }
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
                
                // Find all duplicate groups among these files
                let duplicateGroupsInSize = await findDuplicateGroups(in: files)
                
                if duplicateGroupsInSize.count > 0 {
                    // Add all duplicate groups found
                    for group in duplicateGroupsInSize {
                        duplicateGroups.append(group)
                    }
                    print("🔄 [PROCESS] Found \(duplicateGroupsInSize.count) source-only duplicate groups")
                } else {
                    // No duplicates found - check if any unique files should be moved
                    let uniqueFiles = await findUniqueFiles(in: files)
                    for file in uniqueFiles {
                        let existsInTarget = await fileExistsInTarget(file)
                        if !existsInTarget {
                            filesToMove.append(file)
                            print("🔄 [PROCESS] ✅ File will be moved: \(file.displayName)")
                        } else {
                            print("🔄 [PROCESS] ❌ File exists in target: \(file.displayName)")
                        }
                    }
                }
            }
        }
        
        self.filesToMove = filesToMove
        self.duplicateGroups = duplicateGroups
        progress = 1.0
        currentOperation = "Processing complete"
        print("🔄 [PROCESS] Processing complete: \(filesToMove.count) files to move, \(duplicateGroups.count) duplicate groups")
        
        // Debug: Dump cache information
        dumpCacheInfo()
    }
    
    private func dumpCacheInfo() {
        print("🔍 [CACHE_DUMP] ===== CACHE DUMP START =====")
        
        // Source files cache info
        print("🔍 [CACHE_DUMP] Source Files (\(sourceFiles.count) total):")
        for (index, file) in sourceFiles.enumerated() {
            let status = file.checksumStatus
            print("🔍 [CACHE_DUMP]   [\(index + 1)] \(file.displayName)")
            print("🔍 [CACHE_DUMP]     Size: \(file.formattedSize)")
            print("🔍 [CACHE_DUMP]     Checksums computed:")
            print("🔍 [CACHE_DUMP]       1KB: \(status.hasComputed1KB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       1GB: \(status.hasComputed1GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       4GB: \(status.hasComputed4GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       12GB: \(status.hasComputed12GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       64GB: \(status.hasComputed64GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       128GB: \(status.hasComputed128GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       Full: \(status.hasComputedFull ? "✅" : "❌")")
        }
        
        // Target files cache info
        print("🔍 [CACHE_DUMP] Target Files (\(targetFiles.count) total):")
        for (index, file) in targetFiles.enumerated() {
            let status = file.checksumStatus
            print("🔍 [CACHE_DUMP]   [\(index + 1)] \(file.displayName)")
            print("🔍 [CACHE_DUMP]     Size: \(file.formattedSize)")
            print("🔍 [CACHE_DUMP]     Checksums computed:")
            print("🔍 [CACHE_DUMP]       1KB: \(status.hasComputed1KB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       1GB: \(status.hasComputed1GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       4GB: \(status.hasComputed4GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       12GB: \(status.hasComputed12GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       64GB: \(status.hasComputed64GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       128GB: \(status.hasComputed128GB ? "✅" : "❌")")
            print("🔍 [CACHE_DUMP]       Full: \(status.hasComputedFull ? "✅" : "❌")")
        }
        
        // Summary statistics
        let sourceWithChecksums = sourceFiles.filter { file in
            file.checksumStatus.hasComputed1KB || file.checksumStatus.hasComputed1GB || 
            file.checksumStatus.hasComputed4GB || file.checksumStatus.hasComputed12GB || 
            file.checksumStatus.hasComputed64GB || file.checksumStatus.hasComputed128GB || 
            file.checksumStatus.hasComputedFull
        }.count
        
        let targetWithChecksums = targetFiles.filter { file in
            file.checksumStatus.hasComputed1KB || file.checksumStatus.hasComputed1GB || 
            file.checksumStatus.hasComputed4GB || file.checksumStatus.hasComputed12GB || 
            file.checksumStatus.hasComputed64GB || file.checksumStatus.hasComputed128GB || 
            file.checksumStatus.hasComputedFull
        }.count
        
        print("🔍 [CACHE_DUMP] Summary:")
        print("🔍 [CACHE_DUMP]   Source files with any checksums: \(sourceWithChecksums)/\(sourceFiles.count)")
        print("🔍 [CACHE_DUMP]   Target files with any checksums: \(targetWithChecksums)/\(targetFiles.count)")
        print("🔍 [CACHE_DUMP]   Total files processed: \(sourceFiles.count + targetFiles.count)")
        print("🔍 [CACHE_DUMP] ===== CACHE DUMP END =====")
    }
    
    private func fileExistsInTarget(_ file: FileInfo) async -> Bool {
        print("🔍 [TARGET] Checking if \(file.displayName) exists in target...")
        
        // Check by size and then efficient checksum comparison
        for targetFile in targetFiles {
            if file.size == targetFile.size {
                print("🔍 [TARGET] Size match found, comparing checksums: \(file.displayName) vs \(targetFile.displayName)")
                
                // Log cache state before comparison
                print("🔍 [TARGET] Cache state before comparison:")
                print("🔍 [TARGET]   Source file \(file.displayName) cache: \(formatCacheStatus(file.checksumStatus))")
                print("🔍 [TARGET]   Target file \(targetFile.displayName) cache: \(formatCacheStatus(targetFile.checksumStatus))")
                
                // Create mutable copies for comparison
                var mutableFile = file
                var mutableTargetFile = targetFile
                let isDuplicate = await mutableFile.isDefinitelyDuplicateEfficient(of: mutableTargetFile)
                
                // Update the original arrays with the computed checksums
                if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                    sourceFiles[sourceIndex] = mutableFile
                }
                if let targetIndex = targetFiles.firstIndex(where: { $0.id == targetFile.id }) {
                    targetFiles[targetIndex] = mutableTargetFile
                }
                
                // Log cache state after comparison
                print("🔍 [TARGET] Cache state after comparison:")
                print("🔍 [TARGET]   Source file \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                print("🔍 [TARGET]   Target file \(mutableTargetFile.displayName) cache: \(formatCacheStatus(mutableTargetFile.checksumStatus))")
                
                if isDuplicate {
                    print("🔍 [TARGET] ✅ Found duplicate in target: \(file.displayName)")
                    return true
                } else {
                    print("🔍 [TARGET] ❌ Not a duplicate of target: \(file.displayName)")
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
                
                // Log cache state before comparison
                print("🔍 [TARGET_DUP] Cache state before comparison:")
                print("🔍 [TARGET_DUP]   Source file \(sourceFile.displayName) cache: \(formatCacheStatus(sourceFile.checksumStatus))")
                print("🔍 [TARGET_DUP]   Target file \(targetFile.displayName) cache: \(formatCacheStatus(targetFile.checksumStatus))")
                
                // Create mutable copies for comparison
                var mutableSourceFile = sourceFile
                let (isDuplicate, mutatedTargetFile) = await mutableSourceFile.isDefinitelyDuplicateEfficientWithTarget(of: targetFile)
                
                if isDuplicate {
                    targetDuplicates.append(targetFile)
                    print("🔍 [TARGET_DUP] ✅ Found target duplicate: \(targetFile.displayName)")
                } else {
                    print("🔍 [TARGET_DUP] ❌ Not a duplicate: \(targetFile.displayName)")
                }
                
                // Update the original arrays with the computed checksums
                if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == sourceFile.id }) {
                    sourceFiles[sourceIndex] = mutableSourceFile
                }
                if let targetIndex = targetFiles.firstIndex(where: { $0.id == targetFile.id }) {
                    targetFiles[targetIndex] = mutatedTargetFile
                }
                
                // Log cache state after comparison
                print("🔍 [TARGET_DUP] Cache state after comparison:")
                print("🔍 [TARGET_DUP]   Source file \(mutableSourceFile.displayName) cache: \(formatCacheStatus(mutableSourceFile.checksumStatus))")
                print("🔍 [TARGET_DUP]   Target file \(mutatedTargetFile.displayName) cache: \(formatCacheStatus(mutatedTargetFile.checksumStatus))")
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
            var duplicateReason = ""
            
            // Check against target files
            for targetFile in targetFiles {
                if file.size == targetFile.size {
                    print("🔍 [DUPLICATES] Comparing against target: \(file.displayName) vs \(targetFile.displayName)")
                    
                    // Log cache state before comparison
                    print("🔍 [DUPLICATES] Cache state before comparison:")
                    print("🔍 [DUPLICATES]   Source file \(file.displayName) cache: \(formatCacheStatus(file.checksumStatus))")
                    print("🔍 [DUPLICATES]   Target file \(targetFile.displayName) cache: \(formatCacheStatus(targetFile.checksumStatus))")
                    
                    // Create mutable copies for comparison
                    var mutableFile = file
                    var mutableTargetFile = targetFile
                    if await mutableFile.isDefinitelyDuplicateEfficient(of: mutableTargetFile) {
                        print("🔍 [DUPLICATES] ❌ File is duplicate of target: \(file.displayName)")
                        isDuplicate = true
                        duplicateReason = "duplicate of target file \(targetFile.displayName)"
                        
                        // Update the original arrays with the computed checksums
                        if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                            sourceFiles[sourceIndex] = mutableFile
                        }
                        if let targetIndex = targetFiles.firstIndex(where: { $0.id == targetFile.id }) {
                            targetFiles[targetIndex] = mutableTargetFile
                        }
                        
                        // Log cache state after comparison
                        print("🔍 [DUPLICATES] Cache state after comparison:")
                        print("🔍 [DUPLICATES]   Source file \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                        print("🔍 [DUPLICATES]   Target file \(mutableTargetFile.displayName) cache: \(formatCacheStatus(mutableTargetFile.checksumStatus))")
                        break
                    } else {
                        print("🔍 [DUPLICATES] ✅ File is NOT duplicate of target: \(file.displayName)")
                        
                        // Update the original arrays with the computed checksums
                        if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                            sourceFiles[sourceIndex] = mutableFile
                        }
                        if let targetIndex = targetFiles.firstIndex(where: { $0.id == targetFile.id }) {
                            targetFiles[targetIndex] = mutableTargetFile
                        }
                        
                        // Log cache state after comparison
                        print("🔍 [DUPLICATES] Cache state after comparison:")
                        print("🔍 [DUPLICATES]   Source file \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                        print("🔍 [DUPLICATES]   Target file \(mutableTargetFile.displayName) cache: \(formatCacheStatus(mutableTargetFile.checksumStatus))")
                    }
                }
            }
            
            // Check against other source files (only if not already found to be duplicate)
            if !isDuplicate {
                for otherFile in files {
                    if file != otherFile && file.size == otherFile.size {
                        print("🔍 [DUPLICATES] Comparing against other source: \(file.displayName) vs \(otherFile.displayName)")
                        
                        // Log cache state before comparison
                        print("🔍 [DUPLICATES] Cache state before comparison:")
                        print("🔍 [DUPLICATES]   File \(file.displayName) cache: \(formatCacheStatus(file.checksumStatus))")
                        print("🔍 [DUPLICATES]   Other file \(otherFile.displayName) cache: \(formatCacheStatus(otherFile.checksumStatus))")
                        
                        // Create mutable copies for comparison
                        var mutableFile = file
                        var mutableOtherFile = otherFile
                        if await mutableFile.isDefinitelyDuplicateEfficient(of: mutableOtherFile) {
                            print("🔍 [DUPLICATES] ❌ File is duplicate of other source file: \(file.displayName)")
                            isDuplicate = true
                            duplicateReason = "duplicate of other source file \(otherFile.displayName)"
                            
                            // Update the original arrays with the computed checksums
                            if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                                sourceFiles[sourceIndex] = mutableFile
                            }
                            if let otherSourceIndex = sourceFiles.firstIndex(where: { $0.id == otherFile.id }) {
                                sourceFiles[otherSourceIndex] = mutableOtherFile
                            }
                            
                            // Log cache state after comparison
                            print("🔍 [DUPLICATES] Cache state after comparison:")
                            print("🔍 [DUPLICATES]   File \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                            print("🔍 [DUPLICATES]   Other file \(mutableOtherFile.displayName) cache: \(formatCacheStatus(mutableOtherFile.checksumStatus))")
                            break
                        } else {
                            print("🔍 [DUPLICATES] ✅ File is NOT duplicate of other source: \(file.displayName)")
                            
                            // Update the original arrays with the computed checksums
                            if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                                sourceFiles[sourceIndex] = mutableFile
                            }
                            if let otherSourceIndex = sourceFiles.firstIndex(where: { $0.id == otherFile.id }) {
                                sourceFiles[otherSourceIndex] = mutableOtherFile
                            }
                            
                            // Log cache state after comparison
                            print("🔍 [DUPLICATES] Cache state after comparison:")
                            print("🔍 [DUPLICATES]   File \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                            print("🔍 [DUPLICATES]   Other file \(mutableOtherFile.displayName) cache: \(formatCacheStatus(mutableOtherFile.checksumStatus))")
                        }
                    }
                }
            }
            
            if !isDuplicate {
                duplicates.append(file)
                print("🔍 [DUPLICATES] ✅ File is unique: \(file.displayName) - no duplicates found")
            } else {
                print("🔍 [DUPLICATES] ❌ File is NOT unique: \(file.displayName) - \(duplicateReason)")
            }
        }
        
        // Sort by quality preference
        let sortedDuplicates = duplicates.sorted { $0.isHigherQuality(than: $1) }
        print("🔍 [DUPLICATES] Found \(sortedDuplicates.count) unique files out of \(files.count) total")
        return sortedDuplicates
    }
    
    private func findDuplicateGroups(in files: [FileInfo]) async -> [DuplicateGroup] {
        var groups: [DuplicateGroup] = []
        print("🔍 [DUPLICATES] Finding duplicate groups among \(files.count) files of same size...")
        
        for (index, file) in files.enumerated() {
            print("🔍 [DUPLICATES] Checking file \(index + 1)/\(files.count): \(file.displayName)")
            var isDuplicate = false
            var duplicateReason = ""
            
            // Check against other source files
            for otherFile in files {
                if file != otherFile && file.size == otherFile.size {
                    print("🔍 [DUPLICATES] Comparing against other source: \(file.displayName) vs \(otherFile.displayName)")
                    
                    // Log cache state before comparison
                    print("🔍 [DUPLICATES] Cache state before comparison:")
                    print("🔍 [DUPLICATES]   File \(file.displayName) cache: \(formatCacheStatus(file.checksumStatus))")
                    print("🔍 [DUPLICATES]   Other file \(otherFile.displayName) cache: \(formatCacheStatus(otherFile.checksumStatus))")
                    
                    // Create mutable copies for comparison
                    var mutableFile = file
                    var mutableOtherFile = otherFile
                    if await mutableFile.isDefinitelyDuplicateEfficient(of: mutableOtherFile) {
                        print("🔍 [DUPLICATES] ❌ File is duplicate of other source file: \(file.displayName)")
                        isDuplicate = true
                        duplicateReason = "duplicate of other source file \(otherFile.displayName)"
                        
                        // Update the original arrays with the computed checksums
                        if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                            sourceFiles[sourceIndex] = mutableFile
                        }
                        if let otherSourceIndex = sourceFiles.firstIndex(where: { $0.id == otherFile.id }) {
                            sourceFiles[otherSourceIndex] = mutableOtherFile
                        }
                        
                        // Log cache state after comparison
                        print("�� [DUPLICATES] Cache state after comparison:")
                        print("🔍 [DUPLICATES]   File \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                        print("🔍 [DUPLICATES]   Other file \(mutableOtherFile.displayName) cache: \(formatCacheStatus(mutableOtherFile.checksumStatus))")
                        break
                    } else {
                        print("🔍 [DUPLICATES] ✅ File is NOT duplicate of other source: \(file.displayName)")
                        
                        // Update the original arrays with the computed checksums
                        if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                            sourceFiles[sourceIndex] = mutableFile
                        }
                        if let otherSourceIndex = sourceFiles.firstIndex(where: { $0.id == otherFile.id }) {
                            sourceFiles[otherSourceIndex] = mutableOtherFile
                        }
                        
                        // Log cache state after comparison
                        print("🔍 [DUPLICATES] Cache state after comparison:")
                        print("🔍 [DUPLICATES]   File \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                        print("🔍 [DUPLICATES]   Other file \(mutableOtherFile.displayName) cache: \(formatCacheStatus(mutableOtherFile.checksumStatus))")
                    }
                }
            }
            
            if isDuplicate {
                let group = DuplicateGroup(source: file, targets: []) // Source-only group
                groups.append(group)
                print("🔍 [DUPLICATES] ✅ Found source-only duplicate group: \(file.displayName)")
            }
        }
        
        print("🔍 [DUPLICATES] Found \(groups.count) source-only duplicate groups")
        return groups
    }
    
    private func findUniqueFiles(in files: [FileInfo]) async -> [FileInfo] {
        var uniqueFiles: [FileInfo] = []
        print("🔍 [UNIQUE] Finding unique files among \(files.count) files of same size...")
        
        for (index, file) in files.enumerated() {
            print("🔍 [UNIQUE] Checking file \(index + 1)/\(files.count): \(file.displayName)")
            var isUnique = true
            
            // Check against other source files
            for otherFile in files {
                if file != otherFile && file.size == otherFile.size {
                    print("🔍 [UNIQUE] Comparing against other source: \(file.displayName) vs \(otherFile.displayName)")
                    
                    // Log cache state before comparison
                    print("🔍 [UNIQUE] Cache state before comparison:")
                    print("🔍 [UNIQUE]   File \(file.displayName) cache: \(formatCacheStatus(file.checksumStatus))")
                    print("🔍 [UNIQUE]   Other file \(otherFile.displayName) cache: \(formatCacheStatus(otherFile.checksumStatus))")
                    
                    // Create mutable copies for comparison
                    var mutableFile = file
                    var mutableOtherFile = otherFile
                    if await mutableFile.isDefinitelyDuplicateEfficient(of: mutableOtherFile) {
                        print("🔍 [UNIQUE] ❌ File is duplicate of other source file: \(file.displayName)")
                        isUnique = false
                        break
                    } else {
                        print("🔍 [UNIQUE] ✅ File is NOT duplicate of other source: \(file.displayName)")
                        
                        // Update the original arrays with the computed checksums
                        if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                            sourceFiles[sourceIndex] = mutableFile
                        }
                        if let otherSourceIndex = sourceFiles.firstIndex(where: { $0.id == otherFile.id }) {
                            sourceFiles[otherSourceIndex] = mutableOtherFile
                        }
                        
                        // Log cache state after comparison
                        print("🔍 [UNIQUE] Cache state after comparison:")
                        print("🔍 [UNIQUE]   File \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                        print("🔍 [UNIQUE]   Other file \(mutableOtherFile.displayName) cache: \(formatCacheStatus(mutableOtherFile.checksumStatus))")
                    }
                }
            }
            
            // Check against target files
            for targetFile in targetFiles {
                if file.size == targetFile.size {
                    print("🔍 [UNIQUE] Comparing against target: \(file.displayName) vs \(targetFile.displayName)")
                    
                    // Log cache state before comparison
                    print("🔍 [UNIQUE] Cache state before comparison:")
                    print("🔍 [UNIQUE]   File \(file.displayName) cache: \(formatCacheStatus(file.checksumStatus))")
                    print("🔍 [UNIQUE]   Target file \(targetFile.displayName) cache: \(formatCacheStatus(targetFile.checksumStatus))")
                    
                    // Create mutable copies for comparison
                    var mutableFile = file
                    var mutableTargetFile = targetFile
                    if await mutableFile.isDefinitelyDuplicateEfficient(of: mutableTargetFile) {
                        print("🔍 [UNIQUE] ❌ File is duplicate of target: \(file.displayName)")
                        isUnique = false
                        break
                    } else {
                        print("🔍 [UNIQUE] ✅ File is NOT duplicate of target: \(file.displayName)")
                        
                        // Update the original arrays with the computed checksums
                        if let sourceIndex = sourceFiles.firstIndex(where: { $0.id == file.id }) {
                            sourceFiles[sourceIndex] = mutableFile
                        }
                        if let targetIndex = targetFiles.firstIndex(where: { $0.id == targetFile.id }) {
                            targetFiles[targetIndex] = mutableTargetFile
                        }
                        
                        // Log cache state after comparison
                        print("🔍 [UNIQUE] Cache state after comparison:")
                        print("🔍 [UNIQUE]   File \(mutableFile.displayName) cache: \(formatCacheStatus(mutableFile.checksumStatus))")
                        print("🔍 [UNIQUE]   Target file \(mutableTargetFile.displayName) cache: \(formatCacheStatus(mutableTargetFile.checksumStatus))")
                    }
                }
            }
            
            if isUnique {
                uniqueFiles.append(file)
                print("🔍 [UNIQUE] ✅ File is unique: \(file.displayName) - no duplicates found")
            } else {
                print("🔍 [UNIQUE] ❌ File is NOT unique: \(file.displayName) - \(isUnique ? "duplicate of other source" : "duplicate of target")")
            }
        }
        
        print("🔍 [UNIQUE] Found \(uniqueFiles.count) unique files out of \(files.count) total")
        return uniqueFiles
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
    
    private func formatCacheStatus(_ status: ChecksumStatus) -> String {
        var parts: [String] = []
        if status.hasComputed1KB { parts.append("1KB") }
        if status.hasComputed1GB { parts.append("1GB") }
        if status.hasComputed4GB { parts.append("4GB") }
        if status.hasComputed12GB { parts.append("12GB") }
        if status.hasComputed64GB { parts.append("64GB") }
        if status.hasComputed128GB { parts.append("128GB") }
        if status.hasComputedFull { parts.append("FULL") }
        return parts.isEmpty ? "none" : parts.joined(separator: ", ")
    }
} 

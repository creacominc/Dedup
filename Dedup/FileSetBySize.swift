//
//  FileSetBySize.swift
//  ChecksumTests
//
//  Created by Harold Tomlinson on 2025-10-11.
//

import Foundation

// class representing a map of sets of files collected by size
@Observable
class FileSetBySize: @unchecked Sendable
{
    private(set) var fileSetsBySize: [Int: [MediaFile]] = [:]
    private(set) var lastModified: Date = Date()
    private(set) var lastProcessed: Date = Date()
    
    // MARK: - Subscript Access
    
    /// Direct subscript access - returns copy of array for safety
    subscript (size: Int) -> [MediaFile]? {
        get {
            fileSetsBySize[size]
        }
        set {
            fileSetsBySize[size] = newValue
            lastModified = Date()
        }
    }
    
    // MARK: - Efficient Mutations
    
    /// Appends a file to the set for its size - no unnecessary copying
    func append(_ file: MediaFile) {
        let size = file.fileSize
        // Using default parameter is more efficient - avoids copy-on-write overhead
        fileSetsBySize[size, default: []].append(file)
        lastModified = Date()
    }
    
    /// Appends multiple files - more efficient than calling append repeatedly
    func append<S: Sequence>(contentsOf files: S) where S.Element == MediaFile {
        for file in files {
            fileSetsBySize[file.fileSize, default: []].append(file)
        }
        lastModified = Date()
    }
    
    /// Removes all files from the collection
    func removeAll() {
        fileSetsBySize.removeAll()
        lastModified = Date()
    }

    func remove( mediaFile: MediaFile )
    {
        fileSetsBySize[ mediaFile.fileSize ]?.removeAll { $0.id == mediaFile.id }
        lastModified = Date()
    }


    /// Replaces all contents with another FileSetBySize - O(1) operation
    func replaceAll(with other: FileSetBySize) {
        print("replaceAll called: replacing \(self.totalFileCount) files with \(other.totalFileCount) files")
        fileSetsBySize = other.fileSetsBySize
        lastModified = Date()
        print("After replaceAll: now have \(self.totalFileCount) files")
    }
    
    // MARK: - Efficient Read Access (no array copying)
    
    /// Returns count of files for a given size without copying the array
    func count(for size: Int) -> Int {
        fileSetsBySize[size]?.count ?? 0
    }
    
    /// Checks if any files exist for a given size
    func contains(size: Int) -> Bool {
        fileSetsBySize[size] != nil
    }
    
    /// Returns all unique file sizes in the collection
    var allSizes: [Int] {
        Array(fileSetsBySize.keys)
    }
    
    /// Returns sorted array of sizes (useful for iteration)
    var sortedSizes: [Int] {
        // print( "number of keys: \(fileSetsBySize.count)" )
        // print( "keys: \(fileSetsBySize.keys)" )
        return fileSetsBySize.keys.sorted()
    }

    /// Iterates over files of a given size without copying the array
    func forEach(for size: Int, _ body: (MediaFile) throws -> Void) rethrows {
        // Direct iteration avoids copy-on-write overhead
        guard let files: [MediaFile] = fileSetsBySize[size] else { return }
        for file: MediaFile in files {
            try body(file)
        }
    }
    
    /// Iterates over all files across all sizes without copying arrays
    func forEachFile(_ body: (MediaFile) throws -> Void) rethrows {
        for files: [MediaFile] in fileSetsBySize.values {
            for file: MediaFile in files {
                try body(file)
            }
        }
    }
    
    /// Iterates over each size and its files without copying
    func forEachSize(_ body: (Int, borrowing [MediaFile]) throws -> Void) rethrows {
        for (size, files) in fileSetsBySize {
            try body(size, files)
        }
    }

    /// Total count of all files across all sizes
    var totalFileCount: Int
    {
        fileSetsBySize.values.reduce(0) { $0 + $1.count }
    }

    /// Total count of unique files across all sizes
    var totalUniqueFileCount: Int
    {
        fileSetsBySize.values.reduce(0) { $0 + $1.filter { $0.isUnique }.count }
    }

    /// Unique files
    var uniqueFiles: [MediaFile]
    {
        fileSetsBySize.values.flatMap { $0.filter { $0.isUnique } }
    }

    /// Duplicate files
    var duplicateFiles: [MediaFile]
    {
        fileSetsBySize.values.flatMap { $0.filter { $0.isUnique == false } }
    }

    /// Returns only sizes that have multiple files (potential duplicates)
    var sizesWithMultipleFiles: [Int] {
        fileSetsBySize.filter { $0.value.count > 1 }.map { $0.key }
    }
    
    /// Returns only sizes that have only one file (definiately unique)
    var sizesWithOnlyOneFile: [Int] {
        fileSetsBySize.filter { $0.value.count == 1 }.map { $0.key }
    }

    public func merge(with other: FileSetBySize, sizeLimit: Bool ) -> FileSetBySize
    {
        let result: FileSetBySize = FileSetBySize()
        // copy self to new collection - iterate over values only
        for files: [MediaFile] in self.fileSetsBySize.values
        {
            result.append(contentsOf: files)
        }
        // copy other to new collection
        if sizeLimit {
            // Only merge sizes that exist in self
            let validSizes: Set<Dictionary<Int, [MediaFile]>.Keys.Element> = Set(self.fileSetsBySize.keys)
            for (size, files) in other.fileSetsBySize where validSizes.contains(size)
            {
                result.append(contentsOf: files)
            }
        } else {
            // Merge all sizes from other
            for files: [MediaFile] in other.fileSetsBySize.values
            {
                result.append(contentsOf: files)
            }
        }
        return result
    }

    private func getChecksumSizes( size: Int ) -> [Int]
    {
        // Create a list of Int sizes for checksums, logarithmically spaced
        var checksumSizes: [Int] = []

        let minChunk = 128
        let maxSize = size + minChunk

        // We want to start at 128 and go up to maxSize, using logarithmic spacing
        if maxSize <= minChunk * 2
        {
            checksumSizes = [minChunk, maxSize].filter { $0 <= maxSize }
        }
        else
        {
            let stepCount = 5
            let logMin = log(Double(minChunk))
            let logMax = log(Double(maxSize))
            // At least 5 steps, more as size increases
            for i in 0..<stepCount
            {
                let fraction = Double(i) / Double(stepCount - 1)
                let value = max( exp(logMin + fraction * (logMax - logMin)), Double(minChunk) )
                let roundedValue = (Int(value) / minChunk) * minChunk  // round to nearest 128 bytes
                if roundedValue <= maxSize
                {
                    if checksumSizes.last != roundedValue
                    {
                        checksumSizes.append(roundedValue)
                    }
                }
            }
            // Make sure maxSize is included
            if let last = checksumSizes.last, last < maxSize
            {
                checksumSizes.append(maxSize)
            }
        }
        return checksumSizes
    }


    // Auxiliary for formatting byte sizes (KB, MB, ...)
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MEMORY OPTIMIZATION: Chunk-based deduplication with ADAPTIVE PARALLEL PROCESSING
    // This method uses a dynamic chunk size to read files incrementally,
    // eliminating non-duplicates early without reading entire files.
    // Files are processed in parallel (adaptive concurrency) to maximize CPU and I/O utilization
    // Parallelism adapts based on file count per size: min(fileCount, parallelismThreshold)
    // Chunk size adapts based on memory budget: memoryBudgetGB / numThreads
    // Returns a map of file sizes and the bytes needed to ensure uniqueness
    public func getBytesNeededForUniqueness( currentLevel: @escaping @Sendable (Int) -> Void = { _ in }
                                            , maxLevel: @escaping @Sendable (Int) -> Void = { _ in }
                                            , shouldCancel: @escaping @Sendable () -> Bool = { false }
                                            , updateStatus: @escaping @Sendable (String) -> Void = { _ in }
                                            , memoryBudgetGB: Int = 32  // Memory budget in GB (default: 32GB)
                                            , parallelismThreshold: Int = 16  // Max concurrent tasks (default: 16)
                                            ) async -> [Int:Int]
    {
        // map to be returned.
        var bytesNeeded: [Int:Int] = [:]

        // Mark files as unique where there is only one file for that size
        // Direct iteration avoids copying arrays
        for files: [MediaFile] in fileSetsBySize.values where files.count == 1 {
            files.first!.isUnique = true
            updateStatus( "Size: \(files.first!.fileSize) - Files: \(files.count) -  Marked file as unique: \(files.first!.displayName)" )
        }

        // Get all sizes that need processing (sizes with multiple files)
        let sizesToProcess: [Int] = fileSetsBySize.filter { $0.value.count > 1 }.map { $0.key }
        let totalSizes: Int = sizesToProcess.count
        
        // Update max level on main thread
        DispatchQueue.main.async {
            maxLevel(totalSizes)
            currentLevel(0)
        }
        
        var processedCount = 0

        // for each size of file
        for fileSize in sizesToProcess
        {
            // Check for cancellation
            if shouldCancel() {
                updateStatus("Processing cancelled at size \(fileSize)")
                break
            }

            // Access the array ONCE and reuse the reference - avoids multiple copies
            guard let filesAtSize: [MediaFile] = fileSetsBySize[fileSize] else { continue }
            let fileCount: Int = filesAtSize.count
            let uniquePathCount: Int = Set(filesAtSize.map { $0.fileUrl.path() }).count
            
            // ADAPTIVE PARALLELISM: Calculate optimal concurrency for this file size
            // Use min(fileCount, threshold) to avoid creating more threads than files
            let maxConcurrentTasks = min(fileCount, parallelismThreshold)
            
            // ADAPTIVE CHUNK SIZE: Calculate optimal chunk size based on memory budget
            // Formula: chunkSize = memoryBudget / numThreads
            // This ensures we use available memory efficiently while maintaining high parallelism
            let memoryBudgetBytes = memoryBudgetGB * 1024 * 1024 * 1024
            let optimalChunkSize = max(memoryBudgetBytes / maxConcurrentTasks, 128 * 1024 * 1024)  // Minimum 128MB
            
            // Set the chunk size for this file size processing
            MediaFile.chunkSize = optimalChunkSize
            
            updateStatus("Processing size \(formatBytes(fileSize)) with \(fileCount) files (\(uniquePathCount) unique paths)")
            updateStatus("  Using \(maxConcurrentTasks) threads, chunk size: \(formatBytes(optimalChunkSize))")

            // Warn if there are duplicate file objects
            if fileCount != uniquePathCount {
                updateStatus("  WARNING: \(fileCount - uniquePathCount) duplicate file objects detected!")
            }

            // MEMORY OPTIMIZATION: Calculate maximum number of chunks needed for this file size
            let maxChunks: Int = (fileSize + MediaFile.chunkSize - 1) / MediaFile.chunkSize
            var bytesProcessed: Int = 0
            var allFilesUnique: Bool = false
            
            // Process files chunk by chunk
            // Group files by their checksum signature (concatenated checksums up to current chunk)
            var fileGroups: [String: [MediaFile]] = [:]
            
            // Initialize: all files start in one group
            for file: MediaFile in filesAtSize {
                let key: String = file.fileUrl.path() // Use path as initial grouping key
                fileGroups[key] = [file]
            }
            
            // Process each chunk incrementally
            for chunkIndex: Int in 0..<maxChunks
            {
                // Check for cancellation
                if shouldCancel() {
                    break
                }
                
                // Create new groups based on checksums up to this chunk
                var newGroups: [String: [MediaFile]] = [:]
                
                // Process all files still in contention
                var filesToProcess: [MediaFile] = []
                for group: [MediaFile] in fileGroups.values {
                    filesToProcess.append(contentsOf: group)
                }
                
                // Early exit if all files are already unique
                if filesToProcess.isEmpty {
                    allFilesUnique = true
                    break
                }
                
                updateStatus("  Chunk \(chunkIndex + 1)/\(maxChunks): Processing \(filesToProcess.count) files of size \(formatBytes(fileSize))")
                
                // PARALLEL OPTIMIZATION: Compute checksums concurrently with controlled parallelism
                // Process files in parallel using TaskGroup, limited by maxConcurrentTasks
                await withTaskGroup(of: (MediaFile, String).self) { group in
                    var activeTasks = 0
                    var fileIndex = 0
                    
                    // Start initial batch of tasks
                    while fileIndex < filesToProcess.count && activeTasks < maxConcurrentTasks {
                        let file = filesToProcess[fileIndex]
                        group.addTask {
                            // Each task runs in its own context with autoreleasepool
                            let checksum = await file.computeChunkChecksumAsync(chunkIndex: chunkIndex)
                            return (file, checksum)
                        }
                        activeTasks += 1
                        fileIndex += 1
                    }
                    
                    // Process results and spawn new tasks as old ones complete
                    for await (file, checksum) in group {
                        // NOTE: computeChunkChecksumAsync already stored the checksum in file.checksums[chunkIndex]
                        // We just use the returned value to verify and build the cumulative key
                        
                        // DEBUG: Verify checksum was stored
                        print("FileSetBySize: Received checksum='\(String(checksum.prefix(16)))...' for chunk \(chunkIndex), file='\(file.fileUrl.lastPathComponent)'")
                        print("  File's checksums array now has \(file.checksums.count) elements")
                        if !file.checksums.isEmpty {
                            print(
                                "  First element: '\(String(file.checksums[0]?.prefix(16) ?? "N/A"))...'"
                            )
                        }
                        
                        // Build cumulative checksum key (all chunks up to and including this one) by joining the values (strings)
                        let cumulativeKey = file.checksums.values.joined(separator: "|")
                        // DEBUG: Log the first file of first chunk to verify
                        if chunkIndex == 0 && newGroups.isEmpty {
                            print("FileSetBySize: First file '\(file.fileUrl.lastPathComponent)' checksum value='\(checksum)', array has \(file.checksums.count) elements")
                            if !file.checksums.isEmpty {
                                print(
                                        "  First element: '\(file.checksums[0]?.prefix(32), default: "N/A")...'"
                                )
                            }
                        }
                        
                        // DEBUG: Verify checksums are present
                        if cumulativeKey.isEmpty {
                            print("FileSetBySize ERROR: Got empty cumulative checksum for file '\(file.fileUrl.lastPathComponent)' at chunk \(chunkIndex)")
                            print("  Checksums array: \(file.checksums)")
                            print("  Computed checksum value: '\(checksum)'")
                            print("  Checksums count: \(file.checksums.count)")
                        }
                        
                        // Group files by their cumulative checksum signature
                        newGroups[cumulativeKey, default: []].append(file)
                        
                        // Spawn next task if there are more files to process
                        if fileIndex < filesToProcess.count {
                            let nextFile = filesToProcess[fileIndex]
                            group.addTask {
                                let checksum = await nextFile.computeChunkChecksumAsync(chunkIndex: chunkIndex)
                                return (nextFile, checksum)
                            }
                            fileIndex += 1
                        }
                    }
                }
                
                // Update bytes processed
                bytesProcessed = min((chunkIndex + 1) * MediaFile.chunkSize, fileSize)
                
                // Check if all files are now unique (each group has only one file)
                let uniqueGroups = newGroups.filter { $0.value.count == 1 }
                if uniqueGroups.count == newGroups.count {
                    // All files are now distinguishable
                    allFilesUnique = true
                    updateStatus("  Found uniqueness at chunk \(chunkIndex + 1) (\(formatBytes(bytesProcessed)))")
                    break
                }
                
                // Update fileGroups for next iteration (only keep groups with multiple files)
                fileGroups = newGroups.filter { $0.value.count > 1 }
                
                // If no more groups with duplicates, we're done
                if fileGroups.isEmpty {
                    allFilesUnique = true
                    break
                }
            } // for each chunk
            
            // Mark files as unique or duplicate based on final grouping
            if allFilesUnique {
                // Create final grouping
                var finalGroups: [String: [MediaFile]] = [:]
                for file in filesAtSize {
                    let key = file.checksums.values.joined(separator: "|")
                    finalGroups[key, default: []].append(file)
                }
                
                // Mark files based on group size
                for (key, group) in finalGroups {
                    if group.count == 1 {
                        group[0].isUnique = true
                    } else {
                        // True duplicates - same checksum signature
                        let previewKey = String(key.prefix(min(64, key.count)))
                        print("FileSetBySize: Found \(group.count) duplicate files with checksum signature '\(previewKey)...'")
                        for file in group {
                            file.isUnique = false
                            print("  - \(file.fileUrl.lastPathComponent) has \(file.checksums.count) chunks")
                            // DEBUG: Verify that duplicates have checksums
                            if file.checksums.isEmpty {
                                print("  WARNING: Duplicate file has no checksums! \(file.fileUrl.path())")
                            }
                        }
                    }
                }
                
                bytesNeeded[fileSize] = bytesProcessed

                // DEBUG: Print summary of duplicates found
                let duplicateCount = filesAtSize.filter { !$0.isUnique }.count
                if duplicateCount > 0 {
                    print("Size \(fileSize): Found \(duplicateCount) duplicate files")
                }
            } else {
                // Could not distinguish all files even after reading everything
                let uniquePaths: Set<String> = Set(filesAtSize.map { $0.fileUrl.path() })
                
                print( "Size \(fileSize): WARNING - Could not distinguish all files even after processing all chunks" )
                updateStatus( "  Total file objects: \(fileCount), Unique paths: \(uniquePaths.count)" )
                
                // Check for duplicate file objects (same path appearing multiple times)
                if filesAtSize.count != uniquePaths.count {
                    updateStatus( "  ERROR: Found \(filesAtSize.count - uniquePaths.count) duplicate file objects in the array!" )
                }
                
                // Print the checksums for the duplicate files
                for file in filesAtSize {
                    file.isUnique = false
                    let checksumStr = file.checksums.values.joined(separator: "|")
                    print("\tSize: \(fileSize), \t\(checksumStr) : \(file.fileUrl.path())")
                    // DEBUG: Log detailed checksum info
                    print("  DEBUG: File '\(file.fileUrl.lastPathComponent)' has \(file.checksums.count) checksums")
                    if !file.checksums.isEmpty {
                        print("    First checksum: \(file.checksums[0]?.prefix(32), default: "N/A")...")
                    } else {
                        print("    WARNING: File has NO checksums!")
                    }
                    // CRITICAL DEBUG: Verify checksums persist by checking object identity
                    print("    File object ID: \(ObjectIdentifier(file))")
                    print("    Checksums array address: \(file.checksums)")
                }
                
                // Set bytes needed to file size
                bytesNeeded[fileSize] = fileSize
            }
            
            // Update progress after processing each size
            processedCount += 1
            let currentCount = processedCount
            DispatchQueue.main.async {
                currentLevel(currentCount)
            }
            
            // MEMORY OPTIMIZATION: Drain autoreleasepool more frequently (every 10 sizes)
            if processedCount % 10 == 0 {
                autoreleasepool { }
            }
            
            // Update processing timestamp to signal that isUnique properties have been modified
            lastProcessed = Date()
        } // for each size
        
        return bytesNeeded
    }


    public func extensions() -> [String]
    {
        // return a sorted list of extensions from all files in all sizes
        var allExtensions: Set<String> = []
        // Direct iteration over values avoids copying arrays with keys
        for fileSet: [MediaFile] in self.fileSetsBySize.values
        {
            for file in fileSet
            {
                if let fileExtension = URL(fileURLWithPath: file.fileUrl.path).pathExtension.split(separator: ".").last
                {
                    allExtensions.insert(String(fileExtension))
                }
            }
        }
        return allExtensions.sorted(by: <)
    }
}

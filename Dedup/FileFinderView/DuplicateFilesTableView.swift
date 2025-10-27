//
//  DuplicateFilesTableView.swift
//  ChecksumTests
//
//  Created by Harold Tomlinson on 2025-10-12.
//

import SwiftUI

// Helper struct to represent a row in the duplicate files table
struct DuplicateFileRow: Identifiable {
    let id = UUID()
    let fileName: String
    let filePath: String
    let maxChecksumSize: Int
    let checksumAtMaxSize: String
    let fileSize: Int
}

struct DuplicateFilesTableView: View { 
    // [in] fileSetBySize - files grouped by size
    @Binding var fileSetBySize: FileSetBySize
    
    // Sorting state
    @State private var sortOrder: [KeyPathComparator<DuplicateFileRow>] = [
        .init(\.fileSize, order: .forward)  // Default: sort by file size ascending
    ]
    
    // Compute the list of non-unique files with their checksum information
    private var duplicateFiles: [DuplicateFileRow] {
        var rows: [DuplicateFileRow] = []
        
        // Access lastProcessed to ensure this computed property re-evaluates when uniqueness processing completes
        _ = fileSetBySize.lastProcessed
        
        // Use efficient iteration method to avoid copying arrays
        fileSetBySize.forEachFile { file in
            // Only include files that are not marked as unique
            if !file.isUnique && file.checksums.count >= 1 {
                // Calculate bytes read based on number of chunks
                let chunksRead = file.checksums.count
                let bytesRead = min(chunksRead * MediaFile.chunkSize, file.fileSize)
                
                // Get cumulative checksum signature
                let checksumSignature = file.checksums.values.joined(separator: "|")
                
                rows.append(DuplicateFileRow(
                    fileName: file.fileUrl.lastPathComponent,
                    filePath: file.fileUrl.path,
                    maxChecksumSize: bytesRead,
                    checksumAtMaxSize: checksumSignature,
                    fileSize: file.fileSize
                ))
            }
        }
        
        return rows.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Duplicate Files")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text("Showing \(duplicateFiles.count) non-unique file(s)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Table(duplicateFiles, sortOrder: $sortOrder) {
                TableColumn("File Name", value: \.fileName)
                TableColumn("Path", value: \.filePath)
                TableColumn("File Size", value: \.fileSize) { row in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(row.fileSize), countStyle: .file))
                }
                .width(min: 80, max: 120)
                TableColumn("Max Checksum Size", value: \.maxChecksumSize) { row in
                    Text(ByteCountFormatter.string(fromByteCount: Int64(row.maxChecksumSize), countStyle: .file))
                }
                .width(min: 100, max: 150)
                TableColumn("Checksum at Max Size", value: \.checksumAtMaxSize) { row in
                    Text(row.checksumAtMaxSize.prefix(16) + "...")
                        .font(.system(.caption, design: .monospaced))
                        .help(row.checksumAtMaxSize)
                }
                .width(min: 150, max: 200)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview 
{
    @Previewable @State var fileSetBySize: FileSetBySize = FileSetBySize()
    DuplicateFilesTableView( fileSetBySize: $fileSetBySize )
}

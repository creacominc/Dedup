import SwiftUI
import AVKit
import AppKit

struct DedupProcessView: View
{
    @Binding var statusMsg: String
    @StateObject private var fileProcessor = FileProcessor()
    @State private var selectedFile: FileInfo?
    @State private var selectedTab = 2 // Default to Settings tab
    @Binding var mergedFileSetBySize : FileSetBySize

    var body: some View {
        NavigationView {
            // Sidebar with file list
            FileListView(fileProcessor: fileProcessor, selectedFile: $selectedFile, selectedTab: $selectedTab)
                .frame(minWidth: 300, idealWidth: 350)
            
            // Detail view for selected file
            if let selectedFile = selectedFile {
                if selectedTab == 1 { // Duplicates tab
                    // Find the duplicate group for the selected file
                    if let group = fileProcessor.duplicateGroups.first(where: { $0.source.id == selectedFile.id }) {
                        DuplicateDetailView(sourceFile: group.source, targetFiles: group.targets)
                    } else {
                        // Fallback: show just the selected file
                        FileDetailView(file: selectedFile)
                    }
                } else {
                    FileDetailView(file: selectedFile)
                }
            } else {
                // Placeholder when no file is selected
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    
                    Text("Select a file to preview")
                        .font(.title2)
                        .fontWeight(.medium)
                    
                    Text("Choose a photo, video, or audio file from the list to view it here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
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
}

#Preview {
    @Previewable @State var statusMsg: String = "testing  ..."
    @Previewable @State var mergedFileSetBySize = FileSetBySize()
    DedupProcessView( statusMsg: $statusMsg
                      , mergedFileSetBySize: $mergedFileSetBySize
    )
}

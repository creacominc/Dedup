import SwiftUI

struct FilesToMoveListView: View
{
    @ObservedObject var fileProcessor: FileProcessor
    @Binding var selectedFile: FileInfo?
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
                .accessibilityIdentifier("button-selectAllFiles")
                Button("Move Selected") {
                    Task {
                        await fileProcessor.moveSelectedFiles(Array(selectedFiles))
                        selectedFiles.removeAll()
                        selectAll = false
                    }
                }
                .disabled(selectedFiles.isEmpty)
                .accessibilityIdentifier("button-moveSelectedFiles")
            }
            .padding(.horizontal)
            
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
                List(fileProcessor.filesToMove, id: \.id, selection: $selectedFile) { file in
                    HStack {
                        Button(action: {
                            if selectedFiles.contains(file) {
                                selectedFiles.remove(file)
                            } else {
                                selectedFiles.insert(file)
                            }
                        }) {
                            Image(systemName: selectedFiles.contains(file) ? "checkmark.square.fill" : "square")
                                .foregroundColor(selectedFiles.contains(file) ? .accentColor : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("checkbox-file-\(file.id)")
                        
                        FileRowView(file: file)
                            .onTapGesture {
                                selectedFile = file
                            }
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}


import SwiftUI

struct FilesToMoveListView: View
{
    // [out] statusMsg - update with status
    @Binding var statusMsg: String
    @Binding var mergedFileSetBySize : FileSetBySize
    @State var selectedFile: MediaFile? = nil

//    @ObservedObject var fileProcessor: FileProcessor
//    @Binding var selectedFile: MediaFile?
    @State private var selectedFiles: Set<MediaFile> = []
    @State private var selectAll = false
    
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
//                    Task {
//                        await fileProcessor.moveSelectedFiles(Array(selectedFiles))
//                        selectedFiles.removeAll()
//                        selectAll = false
//                    }
                }
                .disabled( mergedFileSetBySize.totalUniqueFileCount == 0 )
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
                List( mergedFileSetBySize.uniqueFiles, id: \.id, selection: $selectedFile)
                { file in
                    HStack
                    {
                        Button(action: {
//                            if selectedFiles.contains(file)
//                            {
//                                selectedFiles.remove(file)
//                            }
//                            else
//                            {
//                                selectedFiles.insert(file)
//                            }
                        })
                        {
//                            Image(systemName: selectedFiles.contains(file) ? "checkmark.square.fill" : "square")
//                                .foregroundColor(selectedFiles.contains(file) ? .accentColor : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityIdentifier("checkbox-file-\(file.id)")
                        
                        FileRowView(file: file)
                            .onTapGesture {
//                                selectedFile = file
                            }
                    }
                }
                .listStyle(PlainListStyle())
            } // there are files to move
        }
    }
}


#Preview( "with files" )
{
    @Previewable @State var statusMsg: String = "Ready to move files"
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
        mergedFileSetBySize: $mergedFileSetBySize
    )
}


#Preview( "no files" )
{
    @Previewable @State var statusMsg: String = "Ready to move files"
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
        mergedFileSetBySize: $mergedFileSetBySize
    )
}


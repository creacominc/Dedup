import SwiftUI

struct DuplicateDetailView: View {
    let sourceFile: FileInfo
    let targetFiles: [FileInfo]
    
    var body: some View {
        HStack(spacing: 24) {
            VStack {
                Text("Source")
                    .font(.caption)
                    .foregroundColor(.secondary)
                FileDetailView(file: sourceFile)
            }
            ForEach(targetFiles, id: \.id) { targetFile in
                VStack {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    FileDetailView(file: targetFile)
                }
            }
        }
        .padding()
    }
}


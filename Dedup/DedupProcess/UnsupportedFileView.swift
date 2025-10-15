import SwiftUI
import AppKit

struct UnsupportedFileView: View {
    let file: FileInfo
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                Spacer()
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: min(geometry.size.width, geometry.size.height) * 0.15))
                    .foregroundColor(.orange)
                
                Text("Unable to View")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("This file type (\(file.fileExtension.uppercased())) is not supported for preview.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
                }) {
                    Label("Show in Finder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.all, 10) // Reduced padding for more content space
        .onAppear {
            print("DEBUG: UnsupportedFileView appeared for file: \(file.displayName)")
        }
        .onDisappear {
            print("DEBUG: UnsupportedFileView disappeared for file: \(file.displayName)")
        }
    }
}


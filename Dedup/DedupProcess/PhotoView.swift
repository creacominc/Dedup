import SwiftUI
import AppKit

struct PhotoView: View {
    let file: MediaFile
    //    let file: FileInfo
    @State private var image: NSImage?
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 16) {
            if let error = error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Error loading image")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        NSWorkspace.shared.selectFile(file.fileUrl.path, inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path)
                    }) {
                        Label("Show in Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                }
            } else if let image = image {
                GeometryReader { geometry in
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: geometry.size.width > 0 && image.size.height > 0 ? min(geometry.size.width, geometry.size.height * image.size.width / image.size.height) : 100,
                            height: geometry.size.height > 0 && image.size.width > 0 ? min(geometry.size.height, geometry.size.width * image.size.height / image.size.width) : 100
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // No image loaded
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Loading image...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.all, 10) // Reduced padding for more content space
        .onAppear {
            print("DEBUG: PhotoView appeared for file: \(file.displayName)")
            loadImage()
        }
        .onDisappear {
            print("DEBUG: PhotoView disappeared for file: \(file.displayName)")
        }
    }
    
    private func loadImage() {
        print("DEBUG: PhotoView - Starting to load image for: \(file.displayName)")
        guard let image = NSImage(contentsOf: file.fileUrl) else {
            print("DEBUG: PhotoView - Failed to load image from URL: \(file.fileUrl)")
            error = "Could not load image"
            return
        }
        print("DEBUG: PhotoView - Image loaded successfully: \(file.displayName), size: \(image.size)")
        self.image = image
    }
}


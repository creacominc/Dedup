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
            // MEMORY FIX: Explicitly release image to free memory immediately
            cleanupImage()
        }
    }
    
    private func loadImage() {
        print("DEBUG: PhotoView - Starting to load image for: \(file.displayName)")
        
        // MEMORY FIX: Load image with size constraint for thumbnails
        // This reduces memory usage significantly for large images
        guard let image = loadImageWithSizeLimit(url: file.fileUrl, maxDimension: 2048) else {
            print("DEBUG: PhotoView - Failed to load image from URL: \(file.fileUrl)")
            error = "Could not load image"
            return
        }
        print("DEBUG: PhotoView - Image loaded successfully: \(file.displayName), size: \(image.size)")
        self.image = image
    }
    
    private func cleanupImage() {
        // Explicitly nil out the image to release memory immediately
        image = nil
        print("DEBUG: PhotoView - Image released for: \(file.displayName)")
    }
    
    /// MEMORY FIX: Load image with size constraint to reduce memory usage
    private func loadImageWithSizeLimit(url: URL, maxDimension: CGFloat) -> NSImage? {
        // First try to get image metadata without loading full image
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        
        // Get image properties without decoding
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let pixelWidth = imageProperties[kCGImagePropertyPixelWidth] as? CGFloat,
              let pixelHeight = imageProperties[kCGImagePropertyPixelHeight] as? CGFloat else {
            // Fallback to regular loading if we can't get properties
            return NSImage(contentsOf: url)
        }
        
        // Calculate if we need to downsample
        let maxOriginalDimension = max(pixelWidth, pixelHeight)
        if maxOriginalDimension <= maxDimension {
            // Image is small enough, load normally
            return NSImage(contentsOf: url)
        }
        
        // Downsample the image to reduce memory usage
        // let scale = maxDimension / maxOriginalDimension
        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return NSImage(contentsOf: url)
        }
        
        let size = NSSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        let image = NSImage(cgImage: cgImage, size: size)
        
        print("DEBUG: PhotoView - Downsampled image from \(Int(pixelWidth))x\(Int(pixelHeight)) to \(Int(size.width))x\(Int(size.height))")
        return image
    }
}


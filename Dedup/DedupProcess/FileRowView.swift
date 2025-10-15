import SwiftUI
import AppKit

struct FileRowView: View {
    let file: FileInfo
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(file.url.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    Text(file.mediaType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(mediaTypeColor.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text(file.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(file.formattedCreationDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Show in Finder button
            Button(action: {
                NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path)
            }) {
                Image(systemName: "folder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Show in Finder")
        }
        .padding(.vertical, 4)
    }
    
    private var iconName: String {
        switch file.mediaType {
        case .photo:
            return "photo"
        case .video:
            return "video"
        case .audio:
            return "music.note"
        case .unsupported:
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        case .unsupported:
            return .orange
        }
    }
    
    private var mediaTypeColor: Color {
        switch file.mediaType {
        case .photo:
            return .blue
        case .video:
            return .red
        case .audio:
            return .green
        case .unsupported:
            return .orange
        }
    }
}


import SwiftUI
import AppKit

struct DuplicateFileRowView: View
{
//    let group: DuplicateGroup
//    @ObservedObject var fileProcessor: FileProcessor
    
    var body: some View
    {
//        let file = group.source
//        let targetDuplicates = group.targets
        HStack(spacing: 12)
        {
//            Image(systemName: iconName(for: file))
//                .font(.title2)
//                .foregroundColor(iconColor(for: file))
//                .frame(width: 24)
//            
//            VStack(alignment: .leading, spacing: 2)
//            {
//                Text(file.displayName)
//                    .font(.subheadline)
//                    .fontWeight(.medium)
//                
//                Text(file.fileUrl.path)
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .lineLimit(1)
//                    .truncationMode(.middle)
//                
//                HStack(spacing: 8) {
//                    Text(file.mediaType.displayName)
//                        .font(.caption)
//                        .padding(.horizontal, 6)
//                        .padding(.vertical, 2)
//                        .background(mediaTypeColor(for: file).opacity(0.2))
//                        .cornerRadius(4)
//                    
//                    Text(file.formattedSize)
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                    
//                    Text(file.formattedCreationDate)
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//                
//                if !targetDuplicates.isEmpty {
//                    Text("Duplicate of \(targetDuplicates.count) target file(s)")
//                        .font(.caption)
//                        .foregroundColor(.orange)
//                        .padding(.top, 2)
//                    VStack(alignment: .leading, spacing: 2) {
//                        ForEach(targetDuplicates, id: \.id) { targetFile in
//                            HStack(spacing: 4) {
//                                Image(systemName: "arrow.right")
//                                    .font(.caption2)
//                                    .foregroundColor(.secondary)
//                                Text(targetFile.url.path)
//                                    .font(.caption2)
//                                    .foregroundColor(.secondary)
//                                    .lineLimit(1)
//                                    .truncationMode(.middle)
//                            }
//                        }
//                    }
//                    .padding(.top, 4)
//                    .padding(.leading, 8)
//                } else {
//                    Text("Single file in group")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                        .padding(.top, 2)
//                }
//            }
//            
//            Spacer()
//            
//            Button(action: {
//                NSWorkspace.shared.selectFile(file.fileUrl.path, inFileViewerRootedAtPath: file.fileUrl.deletingLastPathComponent().path)
//            }) {
//                Image(systemName: "folder")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//            }
//            .buttonStyle(.plain)
//            .help("Show in Finder")
        }
        .padding(.vertical, 4)
    }
    
    private func iconName(for file: MediaFile) -> String {
        switch file.mediaType {
        case .photo: return "photo"
        case .video: return "video"
        case .audio: return "music.note"
        case .unsupported: return "exclamationmark.triangle"
        }
    }
    private func iconColor(for file: MediaFile) -> Color {
        switch file.mediaType {
        case .photo: return .blue
        case .video: return .red
        case .audio: return .green
        case .unsupported: return .orange
        }
    }
    private func mediaTypeColor(for file: MediaFile) -> Color {
        switch file.mediaType {
        case .photo: return .blue
        case .video: return .red
        case .audio: return .green
        case .unsupported: return .orange
        }
    }
}


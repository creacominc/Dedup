//
//  FileSelectionView.swift
//  ChecksumTests
//
//  Created by Harold Tomlinson on 2025-10-11.
//

import SwiftUI
internal import System

struct FolderSelectionView: View
{
    // [out] URL to be set when the user selects a path
    @Binding var sourceURL: URL?
    @Binding var targetURL: URL?
    // [out] indicates that a folder was selected
    @Binding var sourceFolderSelected: Bool
    @Binding var targetFolderSelected: Bool
    // [in] controls the enablement of the Source button
    @Binding var sourceEnabled: Bool
    @Binding var targetEnabled: Bool
    // [inout] sourceFileSetBySize - reset files grouped by size
    @Binding var sourceFileSetBySize: FileSetBySize
    // [inout] targetFileSetBySize - reset files grouped by size
    @Binding var targetFileSetBySize: FileSetBySize
    // [inout] updateDistribution - set this when updated
    @Binding var updateDistribution: Bool

    var body: some View
    {
        HStack
        {
            VStack
            {
                // source
                HStack
                {
                    Button("Source")
                    {
                        // reset fileSetBySize
                        sourceFileSetBySize.removeAll()
                        // create file open dialog to select a folder
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.canCreateDirectories = false
                        panel.message = "Select source directory containing media files"
                        if panel.runModal() == .OK, let url = panel.url {
                            sourceURL = url
                            sourceFolderSelected = true
                        }
                        else
                        {
                            sourceURL = nil
                            sourceFolderSelected = false
                        }
                    }
                    .disabled( !sourceEnabled )
                    Text( sourceURL?.absoluteString ?? "Select Source Folder" )
                        .frame(maxWidth: .infinity, alignment: .leading)
                } // source
                // folder stats
                FolderStatsView( sourceURL: sourceURL
                               , prompt: "source"
                               , updateDistribution: $updateDistribution
                               , fileSetBySize: $sourceFileSetBySize )
            }
            VStack
            {
                // target
                HStack
                {
                    Button("Target")
                    {
                        // reset fileSetBySize
                        targetFileSetBySize.removeAll()
                        // create file open dialog to select a folder
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        panel.allowsMultipleSelection = false
                        panel.canCreateDirectories = false
                        panel.message = "Select target directory containing media files"
                        if panel.runModal() == .OK, let url = panel.url {
                            targetURL = url
                            targetFolderSelected = true
                        }
                        else
                        {
                            targetURL = nil
                            targetFolderSelected = false
                        }
                    }
                    .disabled( !targetEnabled )
                    Text( targetURL?.absoluteString ?? "Select Target Folder" )
                        .frame(maxWidth: .infinity, alignment: .leading)
                } // target
                FolderStatsView( sourceURL: targetURL
                               , prompt: "target"
                               , updateDistribution: $updateDistribution
                               , fileSetBySize: $targetFileSetBySize )
            }
        } // outter HStack
    } // body
}


#Preview("Specified")
{
    @Previewable @State var sourceURL: URL? = URL(
        filePath: "~/Desktop"
    )
    @Previewable @State var targetURL: URL? = URL(
        filePath: "~/tmp"
    )
    @Previewable @State var sourceFolderSelected: Bool = false
    @Previewable @State var targetFolderSelected: Bool = false
    @Previewable @State var sourceEnabled: Bool = true
    @Previewable @State var targetEnabled: Bool = true
    @Previewable @State var sourceFileSetBySize: FileSetBySize = FileSetBySize()
    @Previewable @State var targetFileSetBySize: FileSetBySize = FileSetBySize()
    @Previewable @State var updateDistribution = false

    // path specified and enabled
    FolderSelectionView( sourceURL: $sourceURL,
                         targetURL: $targetURL,
                         sourceFolderSelected: $sourceFolderSelected,
                         targetFolderSelected: $targetFolderSelected,
                         sourceEnabled: $sourceEnabled,
                         targetEnabled: $targetEnabled,
                         sourceFileSetBySize: $sourceFileSetBySize,
                         targetFileSetBySize: $targetFileSetBySize
                         , updateDistribution: $updateDistribution
    )
}

#Preview("Default")
{
    @Previewable @State var sourceURL: URL? = nil
    @Previewable @State var targetURL: URL? = URL(
        filePath: "~/tmp"
    )
    @Previewable @State var sourceFolderSelected: Bool = false
    @Previewable @State var targetFolderSelected: Bool = false
    @Previewable @State var sourceEnabled: Bool = true
    @Previewable @State var targetEnabled: Bool = true
    @Previewable @State var sourceFileSetBySize: FileSetBySize = FileSetBySize()
    @Previewable @State var targetFileSetBySize: FileSetBySize = FileSetBySize()
    @Previewable @State var updateDistribution = false

    // (default) no file, enabled
    FolderSelectionView( sourceURL: $sourceURL,
                         targetURL: $targetURL,
                         sourceFolderSelected: $sourceFolderSelected,
                         targetFolderSelected: $targetFolderSelected,
                         sourceEnabled: $sourceEnabled,
                         targetEnabled: $targetEnabled,
                         sourceFileSetBySize: $sourceFileSetBySize,
                         targetFileSetBySize: $targetFileSetBySize
                         , updateDistribution: $updateDistribution
    )
}

#Preview("Disabled")
{
    @Previewable @State var sourceURL: URL? = nil
    @Previewable @State var targetURL: URL? = URL(
        filePath: "~/tmp"
    )
    @Previewable @State var sourceFolderSelected: Bool = false
    @Previewable @State var targetFolderSelected: Bool = false
    // disabled selection
    @Previewable @State var sourceEnabled: Bool = true
    @Previewable @State var targetEnabled: Bool = true
    @Previewable @State var sourceFileSetBySize: FileSetBySize = FileSetBySize()
    @Previewable @State var targetFileSetBySize: FileSetBySize = FileSetBySize()
    @Previewable @State var updateDistribution = false

    // no file, disabled
    FolderSelectionView( sourceURL: $sourceURL,
                         targetURL: $targetURL,
                         sourceFolderSelected: $sourceFolderSelected,
                         targetFolderSelected: $targetFolderSelected,
                         sourceEnabled: $sourceEnabled,
                         targetEnabled: $targetEnabled,
                         sourceFileSetBySize: $sourceFileSetBySize,
                         targetFileSetBySize: $targetFileSetBySize
                         , updateDistribution: $updateDistribution
    )
}


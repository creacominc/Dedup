//
//  FileFinderView.swift
//  ChecksumTests
//
//  Created by Harold Tomlinson on 2025-10-04.
//

import SwiftUI

struct FileFinderView: View
{
    // [out] statusMsg - update with status
    @Binding var statusMsg: String
    @State var sourceURL: URL?
    @Binding var targetURL: URL?
    @State var sourceFolderSelected: Bool = false
    @State var targetFolderSelected: Bool = false
    @State var sourceEnabled: Bool = true
    @State var targetEnabled: Bool = true
    @State var sourceFileSetBySize = FileSetBySize()
    @State var targetFileSetBySize = FileSetBySize()
    @Binding var mergedFileSetBySize : FileSetBySize
    @State var updateDistribution: Bool = false
    @State var processEnabled: Bool = false
    @State var currentLevel: Int = 0
    @State var maxLevel: Int = 0

    var body: some View
    {
        VStack()
        {
            // folder picker
            FolderSelectionView(
                sourceURL: $sourceURL,
                targetURL: $targetURL,
                sourceFolderSelected: $sourceFolderSelected,
                targetFolderSelected: $targetFolderSelected,
                sourceEnabled: $sourceEnabled,
                targetEnabled: $targetEnabled,
                sourceFileSetBySize: $sourceFileSetBySize,
                targetFileSetBySize: $targetFileSetBySize
                , updateDistribution: $updateDistribution
            )
            FileSizeDistributionView( sourceFileSetBySize: $sourceFileSetBySize
                                      , targetFileSetBySize: $targetFileSetBySize
                                      , mergedFileSetBySize: $mergedFileSetBySize
                                      , updateDistribution: $updateDistribution
                                      , processEnabled: $processEnabled
            )

            // ChecksumSizeDistribution
            ChecksumSizeDistribution( statusMsg: $statusMsg
                                      , sourceURL: sourceURL
                                      , processEnabled: $processEnabled
                                      , fileSetBySize: $mergedFileSetBySize
                                      , currentLevel: $currentLevel
                                      , maxLevel: $maxLevel
            )

            // progress bar
            ProgressBarView( currentLevel: $currentLevel,
                             maxLevel: $maxLevel )


            // file extensions handled
            FileExtensionsHandledView( fileSetBySize: $mergedFileSetBySize )

            // table of duplicate files
            DuplicateFilesTableView( fileSetBySize: $mergedFileSetBySize )

        } // vstack
        .padding( )
        .onAppear( perform: {
            statusMsg = "Ready"
        } )
        .onChange(of: sourceFileSetBySize.lastModified) { oldValue, newValue in
            // Update merged object when source changes
            mergedFileSetBySize = sourceFileSetBySize.merge(with: targetFileSetBySize, sizeLimit: true)
            statusMsg = "Merge on change of source.  Size: \(mergedFileSetBySize.totalFileCount) vs \(sourceFileSetBySize.totalFileCount)"
        }
        .onChange(of: targetFileSetBySize.lastModified) { oldValue, newValue in
            // Update merged object when target changes
            mergedFileSetBySize = sourceFileSetBySize.merge(with: targetFileSetBySize, sizeLimit: true)
            statusMsg = "Merge on change of target.  Size: \(mergedFileSetBySize.totalFileCount) vs \(sourceFileSetBySize.totalFileCount)"
        }
    }
}

#Preview {
    @Previewable @State var statusMsg: String = "testing  ..."
    @Previewable @State var mergedFileSetBySize = FileSetBySize()
    @Previewable @State var targetURL: URL?

    FileFinderView( statusMsg: $statusMsg
                    , targetURL: $targetURL
                    , mergedFileSetBySize: $mergedFileSetBySize
    )
}

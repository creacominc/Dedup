//
//  FileFinderView.swift
//  ChecksumTests
//
//  Created by Harold Tomlinson on 2025-10-04.
//

import SwiftUI

struct FileFinderView: View
{
    @Binding var statusMsg: String
    @State var sourceURL: URL?
    @State var targetURL: URL?
    @State var sourceFolderSelected: Bool = false
    @State var targetFolderSelected: Bool = false
    @State var sourceEnabled: Bool = true
    @State var targetEnabled: Bool = true
    @State var sourceFileSetBySize = FileSetBySize()
    @State var targetFileSetBySize = FileSetBySize()
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
                                      , updateDistribution: $updateDistribution
                                      , processEnabled: $processEnabled
            )

            // ChecksumSizeDistribution
            ChecksumSizeDistribution( sourceURL: sourceURL
                                      , processEnabled: $processEnabled
                                      , fileSetBySize: $sourceFileSetBySize
                                      , currentLevel: $currentLevel
                                      , maxLevel: $maxLevel )

            // progress bar
            ProgressBarView( currentLevel: $currentLevel,
                             maxLevel: $maxLevel )


            // file extensions handled
            FileExtensionsHandledView( fileSetBySize: $sourceFileSetBySize )

            // table of duplicate files
            DuplicateFilesTableView( fileSetBySize: $sourceFileSetBySize )

        } // vstack
        .padding( )
        .onAppear( perform: {
            statusMsg = "Ready"
        } )
    }
}

#Preview {
    @Previewable @State var statusMsg: String = "testing  ..."
    FileFinderView( statusMsg: $statusMsg )
}

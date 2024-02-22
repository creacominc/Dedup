//
//  DuplicateManagement.swift
//  Dedup
//
//  Created by Harold Tomlinson on 2023-10-28.
//

import SwiftUI

struct DuplicateManagement: View 
{
    @Binding var folderDuplicateCounts: FolderDuplicateCountData
    @Binding var isPresented: Bool
    
    var body: some View
    {
        VStack
        {
            VStack
            {
                Text( "Folder size: \(folderDuplicateCounts.size)" )
                Text( "Folder duplicate count: \(folderDuplicateCounts.count)" )
                Text( "Folder path: \(folderDuplicateCounts.path)" )
            }
            .padding()
            VStack
            {
                ForEach(folderDuplicateCounts.files, id: \.self, content: { fileName in
                    Text( "\(fileName)" )
                })
            }
            .padding()
            VStack
            {
                ForEach(folderDuplicateCounts.matchingFolders, id: \.self, content: { pathName in
                    Text( "\(pathName)" )
                })
            }
            .padding()
            Button( "Done" )
            {
                isPresented = false
            }
        }
        .padding()
    }


}


struct DuplicateManagement_Previews: PreviewProvider {

    static var previews: some View 
    {
        @State var folderDuplicateCountsData = FolderDuplicateCountData( count: 3, size: 3000, path: "path/to/file",
                                                    files: [ "sampleFile0", "sampleFile1", "matchingFile" ],
                                                    matching: [ "other/folder/0", "other/folder/1" ]
        )
        @State var isPresented : Bool = true
        DuplicateManagement( folderDuplicateCounts: $folderDuplicateCountsData,
                             isPresented: $isPresented )
    }

}

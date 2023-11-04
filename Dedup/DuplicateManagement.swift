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
            Text( "\(folderDuplicateCounts.size)" )
            Text( "\(folderDuplicateCounts.count)" )
            Text( folderDuplicateCounts.path )
            Button( "Done" )
            {
                isPresented = false
            }
        }
        .padding()
    }
}

//#Preview {
//    DuplicateManagement()
//}

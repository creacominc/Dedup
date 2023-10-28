//
//  FolderDuplicateCountData.swift
//  Dedup
//
//  Created by Harold Tomlinson on 2023-10-28.
//

import Foundation


class FolderDuplicateCountData: Identifiable
{
    let id = UUID()
    var count: Int
    var path: String


    init( count : Int, path: String )
    {
        self.count = count
        self.path = path
    }

}

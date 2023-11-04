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
    var size: Int64
    var path: String

    init( count : Int, size: Int64, path: String )
    {
        self.count = count
        self.size  = size
        self.path = path
    }

}

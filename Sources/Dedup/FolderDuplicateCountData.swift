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
    var files: [String] = []
    var matchingFolders: [String] = []

    init( count : Int, size: Int64, path: String, files : [String]? = [], matching : [String]? = [] )
    {
        self.count = count
        self.size  = size
        self.path = path
        if( files != nil )
        {
            self.files = files!
        }
        if( matching != nil )
        {
            self.matchingFolders = matching!
        }
    }

}


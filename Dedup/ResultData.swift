//
//  ResultData.swift
//  Dedup
//
//  Created by Harold Tomlinson on 2023-10-19.
//

import Foundation

class ResultData: Identifiable
{
    let id = UUID()
    var size: Int
    var checksum: String
    var fcount: Int
    var files: [String]

    init( size : Int, checksum: String )
    {
        self.size = size
        self.checksum = checksum
        self.fcount = 0
        self.files = []
    }

    func AddFile( file: String )
    {
        self.files.append( file )
        self.fcount += 1
    }

    func getFiles() -> String
    {
        var allFiles : String = ""
        var separator : String = ""
        files.forEach { path in
            allFiles += separator + path
            separator = ", "
        }
        return allFiles
    }
}

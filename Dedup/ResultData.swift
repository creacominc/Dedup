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
    var count: Int
    var files: String

    init( size : Int, checksum: String )
    {
        self.size = size
        self.checksum = checksum
        self.count = 0
        self.files = ""
    }

    func AddFile( file: String )
    {
        if( self.files.isEmpty )
        {
            self.files = file
            self.count = 1
        }
        else
        {
            self.files = self.files + ", " + file
            self.count += 1
        }
    }

}

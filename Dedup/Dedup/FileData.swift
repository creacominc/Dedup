//
//  FileData.swift
//  Dedup
//
//  Created by Harold Tomlinson on 2023-10-03.
//

import Foundation

struct FileData: Identifiable
{
    let id = UUID()
    var path: String
    var size: Int64
    var checksum: String
    var sumSize:  Int64
}

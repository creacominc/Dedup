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
    var path: URL
    var size: Int
    var checksum: Data
    var sumSize:  Int
}

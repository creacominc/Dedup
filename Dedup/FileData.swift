//
//  FileData.swift
//  Dedup
//
//  Created by Harold Tomlinson on 2023-10-03.
//

import Foundation
import CryptoKit
import CommonCrypto

class FileData: Identifiable
{
    let id = UUID()
    var path: URL
    var size: Int
    var checksum: String
    var bufferSize: Int
    var bytesRead: UInt64
    var context : CC_MD5_CTX;

    let fileKeys : [URLResourceKey] = [
        URLResourceKey.fileSizeKey,
        URLResourceKey.isDirectoryKey,
        URLResourceKey.nameKey,
        URLResourceKey.contentModificationDateKey,
        URLResourceKey.creationDateKey,
        URLResourceKey.fileAllocatedSizeKey,
        URLResourceKey.isAliasFileKey,
        URLResourceKey.isReadableKey,
        URLResourceKey.isRegularFileKey,
        URLResourceKey.isSymbolicLinkKey,
    ]

    init( path : URL  )
    {
        self.path = path
        self.checksum = ""
        self.bufferSize = 4096 // start with a small buffer to quickly find significantly different files.
        self.bytesRead = 0
        self.context = CC_MD5_CTX()
        self.size = 0
        CC_MD5_Init(&context) // initialize MD5 context
        // get the file size
        do
        {
            let fileAttributes = try self.path.resourceValues(forKeys: Set(self.fileKeys) )
            self.size = fileAttributes.fileSize!
        }
        catch
        {
            print("Cannot stat file \(path):", error.localizedDescription)
        }
    }
    
    func md5()
    {
        do {
            // Open file for reading:
            let file = try FileHandle(forReadingFrom: self.path)
            defer {
                file.closeFile()
            }
            // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
            try autoreleasepool(invoking: {
                try file.seek(toOffset: bytesRead)  //  Seek to bytesRead
                let data = file.readData(ofLength: bufferSize) // read data
                if data.count > 0
                {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&self.context, $0.baseAddress, numericCast(data.count))
                    }
                    // increment bytesRead
                    self.bytesRead += UInt64(data.count)
                }
            })
            // Compute the MD5 digest:
            var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = CC_MD5_Final(&digest, &self.context)
            self.checksum = ""
            self.bufferSize =  4194304  // read in 4M increments after initial read.

            digest.forEach({ (val) in
                self.checksum.append( String(format: "%02hhx", val) )
            })
        } catch {
            print("Cannot open file:", error.localizedDescription)
        }
    }
    
}

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
    var checksum: Data
    
    init( path : URL, size : Int )
    {
        self.path = path
        self.size = size
        
        self.checksum = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
    }
    
    func md5File() -> Data?
    {
        let bufferSize = 1024 * 1024
        do {
            // Open file for reading:
            let file = try FileHandle(forReadingFrom: self.path)
            defer {
                file.closeFile()
            }
            // Create and initialize MD5 context:
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)
            // Read up to `bufferSize` bytes, until EOF is reached, and update MD5 context:
            while autoreleasepool(invoking: {
                let data = file.readData(ofLength: bufferSize)
                if data.count > 0 {
                    data.withUnsafeBytes {
                        _ = CC_MD5_Update(&context, $0.baseAddress, numericCast(data.count))
                    }
                    return true // Continue
                } else {
                    return false // End of file
                }
            }) { }
            // Compute the MD5 digest:
            var digest: [UInt8] = Array(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            _ = CC_MD5_Final(&digest, &context)
            return Data(digest)
        } catch {
            print("Cannot open file:", error.localizedDescription)
            return nil
        }
    }

    
}

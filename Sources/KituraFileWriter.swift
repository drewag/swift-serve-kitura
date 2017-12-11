//
//  KituraLogger.swift
//  SwiftServeKitura
//
//  Created by Andrew J Wagner on 11/26/16.
//
//

import Foundation
import SwiftServe
import Swiftlier

public final class KituraFileWriter: FileWriter {
    private var handle: FileHandle? = nil

    public init(path: String) {
        do {
            let url = URL(fileURLWithPath: path)
            let path = FileSystem.default.path(from: url)
            let file = try path.file ?? path.createFile(containing: Data(), canOverwrite: true)
            self.handle = try file.handleForWriting()
        }
        catch let error {
            print("Error opening log: \(error)")
        }
    }

    public func write(_ text: String) -> Bool {
        guard let handle = self.handle else {
            print(text)
            return false
        }

        handle.write(text.data(using: .utf8) ?? Data())
        handle.write("\n".data(using: .utf8) ?? Data())
        handle.synchronizeFile()
        return true
    }
}

//
//  KituraLogger.swift
//  SwiftServeKitura
//
//  Created by Andrew J Wagner on 11/26/16.
//
//

import SwiftServe
import File

public final class KituraFileWriter: FileWriter {
    private var file: File? = nil

    public init(path: String) {
        do {
            self.file = try File(path: path, mode: .appendWrite)
        }
        catch let error {
            print("Error opening log: \(error)")
        }
    }

    public func write(_ text: String) -> Bool {
        guard let file = self.file else {
            print(text)
            return false
        }

        do {
            try file.write(text)
            try file.write("\n")
            try file.flush(deadline: 0)
            return true
        }
        catch {
            print(text)
            return false
        }
    }
}

extension File {
    func write(_ string: String) throws {
        try self.write(string, deadline: 0)
    }
}


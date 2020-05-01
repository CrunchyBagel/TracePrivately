//
//  DataExtension.swift
//  TracePrivately
//

import Foundation

extension UUID {
    var data: Data {
        return withUnsafePointer(to: self.uuid) {
            Data(bytes: $0, count: MemoryLayout.size(ofValue: self.uuid))
        }
    }
}

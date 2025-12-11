//
//  Item.swift
//  Roots
//
//  Created by Cleveland Lewis III on 11/30/25.
//

#if !DISABLE_SWIFTDATA
import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
#endif

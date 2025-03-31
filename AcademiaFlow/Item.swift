//
//  Item.swift
//  AcademiaFlow
//
//  Created by Shubham Tomar on 31/03/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

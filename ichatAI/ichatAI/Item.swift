//
//  Item.swift
//  ichatAI
//
//  Created by 龙 on 2026/9/2.
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

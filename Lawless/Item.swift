//
//  Item.swift
//  Lawless
//
//  Created by powertex1 on 17.09.26.
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

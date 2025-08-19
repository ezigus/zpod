//
//  Item.swift
//  zpodcastaddict
//
//  Created by Eric Ziegler on 7/12/25.
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

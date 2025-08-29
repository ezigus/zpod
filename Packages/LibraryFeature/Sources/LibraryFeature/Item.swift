//
//  Item.swift
//  zpodcastaddict
//
//  Created by Eric Ziegler on 7/12/25.
//

import Foundation
import SwiftData

@Model
public final class Item {
    public var timestamp: Date
    
    public init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
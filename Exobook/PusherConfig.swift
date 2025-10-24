//
//  PusherConfig.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

enum PusherConfig {
    static let key: String = {
        guard let key = ProcessInfo.processInfo.environment["PUSHER_KEY"] else {
            fatalError("PUSHER_KEY environment variable not set. Please configure it in Xcode scheme.")
        }
        return key
    }()
    
    static let cluster = "mt1"
}

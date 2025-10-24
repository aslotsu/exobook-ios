//
//  PusherManager.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//


import SwiftUI
import Combine
import PusherSwift

final class PusherManager: ObservableObject {
    @Published var messages: [String] = []

    private var pusher: Pusher!
    private var channel: PusherChannel?

    init() {
        // Replace with your actual key & cluster, e.g. "mt1", "eu", "us2", etc.
        let options = PusherClientOptions(host: .cluster("YOUR_CLUSTER"))
        pusher = Pusher(key: "YOUR_KEY", options: options)

        // Optional logging during dev
        pusher.connection.delegate = self

        // Subscribe to a channel
        channel = pusher.subscribe("public-chat")

        // Bind to an event
        _ = channel?.bind(eventName: "message") { [weak self] data in
            guard let self else { return }
            if let dict = data as? [String: Any],
               let text = dict["text"] as? String {
                DispatchQueue.main.async { self.messages.append(text) }
            } else {
                DispatchQueue.main.async { self.messages.append("\(data)") }
            }
        }

        // Connect
        pusher.connect()
    }

    deinit {
        channel?.unbindAll()
        pusher.unsubscribe("public-chat")
        pusher.disconnect()
    }
}

extension PusherManager: PusherDelegate {
    func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        print("Pusher state: \(old.stringValue()) → \(new.stringValue())")
    }
    func debugLog(message: String) {
        print("Pusher:", message)
    }
}

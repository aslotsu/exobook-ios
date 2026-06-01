//
//  RealtimeBanner.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import SwiftUI

struct RealtimeBanner: View {
    @State private var isVisible = false
    @State private var title: String = ""
    @State private var message: String = ""
    @State private var hideWorkItem: DispatchWorkItem?

    var body: some View {
        VStack {
            if isVisible {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        if !message.isEmpty {
                            Text(message)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    Spacer(minLength: 0)
                    Button {
                        hide()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(.white.opacity(0.9))
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                        .opacity(0.9)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RealtimeNotification"))) { notif in
            guard let info = notif.userInfo as? [String: Any] else { return }
            let newTitle = (info["title"] as? String) ?? "Notification"
            let newMessage = (info["body"] as? String) ?? ""
            show(title: newTitle, message: newMessage)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.2), value: isVisible)
    }

    private func show(title: String, message: String) {
        self.title = title
        self.message = message
        self.isVisible = true

        // Cancel any pending hide
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { hide() }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }

    private func hide() {
        withAnimation {
            self.isVisible = false
        }
    }
}
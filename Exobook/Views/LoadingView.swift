//
//  LoadingView.swift
//  Exobook
//
//  Created by Alfred Lotsu on 21/12/2025.
//

import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false
    @State private var dotsCount = 0
    @State private var currentMessageIndex = 0
    @Environment(\.colorScheme) private var colorScheme

    // Cool loading messages
    private let loadingMessages = [
        "Connecting you",
        "Lightning fast ⚡",
        "Almost there",
        "Getting things ready"
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 15/255, green: 23/255, blue: 42/255), Color(red: 30/255, green: 41/255, blue: 59/255)]
                    : [Color.white, Color(red: 248/255, green: 250/255, blue: 252/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Logo or app name with animation
                VStack(spacing: 16) {
                    // Animated logo icon
                    Image(systemName: "book.fill")
                        .font(.system(size: 80, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true),
                            value: isAnimating
                        )

                    // App name
                    Text("Exobook")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                // Loading indicator
                VStack(spacing: 12) {
                    // Custom animated dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 12, height: 12)
                                .opacity(dotsCount == index ? 1.0 : 0.3)
                                .scaleEffect(dotsCount == index ? 1.2 : 1.0)
                                .animation(
                                    Animation.easeInOut(duration: 0.5),
                                    value: dotsCount
                                )
                        }
                    }

                    // Rotating loading message
                    Text(loadingMessages[currentMessageIndex])
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                        .id("message-\(currentMessageIndex)") // Force view refresh
                }
                .padding(.top, 8)
            }
        }
        .onAppear {
            isAnimating = true
            startDotsAnimation()
            startMessageRotation()
        }
    }

    private func startDotsAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation {
                dotsCount = (dotsCount + 1) % 3
            }
        }
    }

    private func startMessageRotation() {
        // Pick a random starting message
        currentMessageIndex = Int.random(in: 0..<loadingMessages.count)

        // Rotate through messages every 700ms
        Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentMessageIndex = (currentMessageIndex + 1) % loadingMessages.count
            }
        }
    }
}

#Preview {
    LoadingView()
}

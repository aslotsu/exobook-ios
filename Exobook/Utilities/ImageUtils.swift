//
//  ImageUtils.swift
//  Exobook
//
//  Created by Alfred Lotsu on 03/01/2026.
//

import SwiftUI
import SDWebImageSwiftUI

// MARK: - Avatar Utilities

/// Extracts initials from a user's name following the avatar system rules
/// - Multiple names: First letter of first name + First letter of last name
/// - Single name: First two letters
/// - Special characters are removed, only A-Z kept
/// - Always uppercase
func getInitials(from name: String) -> String {
    let cleaned = name.uppercased()
        .components(separatedBy: CharacterSet.letters.inverted)
        .joined()
    
    let parts = cleaned.components(separatedBy: " ")
        .filter { !$0.isEmpty }
    
    if parts.isEmpty { return "A" }
    
    if parts.count == 1 {
        let part = parts[0]
        return part.count >= 2 ? String(part.prefix(2)) : String(part.prefix(1))
    } else {
        return "\(parts.first!.prefix(1))\(parts.last!.prefix(1))"
    }
}

/// Generates a CloudFront avatar URL based on user initials
/// Uses the blue-light theme as default, consistent with the web app
func generateCloudFrontAvatarURL(for name: String) -> String {
    let initials = getInitials(from: name)
    return "https://djqsp5ejhqi2j.cloudfront.net/png/blue-light-\(initials).png"
}

/// Checks if a URL is a CloudFront generated avatar
func isGeneratedAvatar(_ url: String) -> Bool {
    return url.contains("djqsp5ejhqi2j.cloudfront.net/png/")
}

// MARK: - Profile Image View

// Reusable profile image view with CloudFront URL fallback
struct ProfileImageView: View {
    let imageURL: URL?
    let userName: String? // Used for generating fallback CloudFront URL
    let size: CGFloat
    
    var body: some View {
        let finalURL = imageURL ?? fallbackCloudFrontURL
        
        WebImage(url: finalURL)
            .onSuccess { image, data, cacheType in
                print("✅ DEBUG_PROFILE_IMAGE: Successfully loaded image from URL: \(finalURL?.absoluteString ?? "nil")")
                if let data = data {
                    print("📊 DEBUG_PROFILE_IMAGE: Image data size: \(data.count) bytes")
                }
            }
            .onFailure { error in
                print("❌ DEBUG_PROFILE_IMAGE: Failed to load image from URL: \(finalURL?.absoluteString ?? "nil")")
                print("❌ DEBUG_PROFILE_IMAGE: Error: \(error.localizedDescription)")
            }
//            .placeholder {
//                // Show a simple circle placeholder while loading
//                Circle()
//                    .fill(Color.gray.opacity(0.3))
//                    .frame(width: size, height: size)
//            }
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
    
    /// Generates a CloudFront URL based on user's name initials as fallback
    private var fallbackCloudFrontURL: URL? {
        guard let userName = userName, !userName.isEmpty else {
            // If no name provided, use "A" as default
            return URL(string: "https://djqsp5ejhqi2j.cloudfront.net/png/blue-light-A.png")
        }
        let cloudFrontURLString = generateCloudFrontAvatarURL(for: userName)
        return URL(string: cloudFrontURLString)
    }
}

// Reusable post image view with proper error handling
struct PostImageView: View {
    let imageURL: URL
    let aspectRatio: CGFloat
    
    var body: some View {
        WebImage(url: imageURL)
            .resizable()
            .indicator(.activity)
            .scaledToFill()
            .aspectRatio(aspectRatio, contentMode: .fill)
            .clipped()
            .cornerRadius(8)
//            .onFailure { _ in
//                // Image failed to load - could add a placeholder here
//            }
    }
}

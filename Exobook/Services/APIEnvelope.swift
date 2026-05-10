import Foundation

/// Standard `{success, data, message?}` envelope used by the chats-exobook,
/// friends, and dynamodb services. Use this instead of declaring a private
/// nested response type per call site.
struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T
    let message: String?
}

/// Variant where the payload may be missing on error responses.
struct OptionalAPIEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
}

/// Variant for endpoints that return `{success, message}` with no payload
/// (e.g., mark-as-read).
struct StatusEnvelope: Decodable {
    let success: Bool
    let message: String?
}

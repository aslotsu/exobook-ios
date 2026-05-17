//
//  NetworkService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation
import os

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case encodingError(Error)
    case noData
    case unauthorized
    case serverError(String)
}

@MainActor
class NetworkService {
    static let shared = NetworkService()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// Optional async provider that returns a Bearer token to attach to outgoing requests.
    /// Set this from app startup; return nil to skip the header for a given call.
    var authTokenProvider: (() async -> String?)?

    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        // Remove data size limits for large API responses
        configuration.urlCache = URLCache(memoryCapacity: 50_000_000, diskCapacity: 100_000_000)
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
        // Don't use .convertFromSnakeCase - it conflicts with custom CodingKeys
        // Each model should define its own CodingKeys for snake_case mapping
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        // Don't use .convertToSnakeCase - each model should define its own CodingKeys
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    // MARK: - HTTP Methods
    
    func get<T: Decodable>(
        _ endpoint: String,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await request(endpoint, method: "GET", headers: headers)
    }
    
    func post<T: Decodable, Body: Encodable>(
        _ endpoint: String,
        body: Body,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await request(endpoint, method: "POST", body: body, headers: headers)
    }
    
    func put<T: Decodable, Body: Encodable>(
        _ endpoint: String,
        body: Body,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await request(endpoint, method: "PUT", body: body, headers: headers)
    }
    
    func patch<T: Decodable, Body: Encodable>(
        _ endpoint: String,
        body: Body,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await request(endpoint, method: "PATCH", body: body, headers: headers)
    }
    
    func delete<T: Decodable>(
        _ endpoint: String,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await request(endpoint, method: "DELETE", headers: headers)

    }

    func delete<T: Decodable, Body: Encodable>(
        _ endpoint: String,
        body: Body,
        headers: [String: String]? = nil
    ) async throws -> T {
        try await request(endpoint, method: "DELETE", body: body, headers: headers)
    }
    
    func upload<T: Decodable>(
        _ endpoint: String,
        data: Data,
        boundary: String,
        headers: [String: String]? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = data

        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let provider = authTokenProvider, let token = await provider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        Log.api.debug("UPLOAD \(endpoint, privacy: .public) (\(data.count, privacy: .public) bytes)")

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        Log.api.debug("\(httpResponse.statusCode, privacy: .public) UPLOAD \(endpoint, privacy: .public)")
        
        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: responseData)
            } catch {
                throw NetworkError.decodingError(error)
            }
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        case 500...599:
            let message = String(data: responseData, encoding: .utf8) ?? "Server error"
            throw NetworkError.serverError(message)
        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Generic Request
    
    private func request<T: Decodable, Body: Encodable>(
        _ endpoint: String,
        method: String,
        body: Body? = nil as EmptyBody?,
        headers: [String: String]? = nil
    ) async throws -> T {
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        // Only GET is guaranteed to never have a body.
        if method != "GET" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let provider = authTokenProvider, let token = await provider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body if present and not a GET request.
        if let body = body as? (any Encodable), method != "GET", !(body is EmptyBody) {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }
        
        Log.api.debug("\(method, privacy: .public) \(endpoint, privacy: .public)")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            Log.api.debug("body \(bodyString, privacy: .private(mask: .hash))")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        Log.api.debug("\(httpResponse.statusCode, privacy: .public) \(method, privacy: .public) \(endpoint, privacy: .public)")
        
        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        case 500...599:
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw NetworkError.serverError(message)
        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - Helper Types

private struct EmptyBody: Encodable {}

struct EmptyResponse: Decodable {}

extension NetworkError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        case .unauthorized:
            return "Unauthorized - please log in"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

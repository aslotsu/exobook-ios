//
//  NetworkService.swift
//  Exobook
//
//  Created by Alfred Lotsu on 24/10/2025.
//

import Foundation

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
        
        // Log request (debug only)
        #if DEBUG
        print("🌐 [UPLOAD] \(endpoint)")
        print("📦 Data size: \(data.count) bytes")
        #endif
        
        let (responseData, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Log response (debug only)
        #if DEBUG
        print("📥 [\(httpResponse.statusCode)] \(endpoint)")
        if let responseString = String(data: responseData, encoding: .utf8) {
            print("📄 Response: \(responseString)")
        }
        #endif
        
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
        
        // Only set Content-Type for methods that have bodies
        if method != "GET" && method != "DELETE" {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add body if present and NOT a GET/DELETE request
        if let body = body as? (any Encodable), method != "GET", method != "DELETE", !(body is EmptyBody) {
            do {
                request.httpBody = try encoder.encode(body)
            } catch {
                throw NetworkError.encodingError(error)
            }
        }
        
        // Log request (debug only)
        #if DEBUG
        print("🌐 [\(method)] \(endpoint)")
        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            print("📦 Body: \(bodyString)")
        }
        #endif
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Log response (debug only)
        #if DEBUG
        print("📥 [\(httpResponse.statusCode)] \(endpoint)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("📄 Response: \(responseString)")
        }
        #endif
        
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

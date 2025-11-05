//
//  RemoteLoader.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

final class RemoteLoader {
    private var token: AccessToken?
    private let client: HTTPClient
    private let baseURL: URL
    init(client: HTTPClient, baseURL: URL) {
        self.client = client
        self.baseURL = baseURL
    }
    
    func sign(with token: AccessToken) {
        self.token = token
    }
    
    private func request(for path: String) -> URLRequest {
        URLRequest(url: baseURL.appendingPathComponent(path))
    }
    
    private func signedRequest(for path: String) -> URLRequest? {
        guard let token = token, token.isValid else {
            return nil
        }
        var signedRequest = request(for: path)
        signedRequest.setValue("Bearer \(token.value)", forHTTPHeaderField: "Authorization")
        return signedRequest
    }
}

extension RemoteLoader {
    enum Error: LocalizedError {
        case invalidLoginOrPassword
        case serverUnavailable
        case unauthorized
        case notFound
        
        var errorDescription: String? {
            switch self {
            case .invalidLoginOrPassword:
                return "Invalid login or password"
            case .serverUnavailable:
                return "Server is unavailable, try again later"
            case .unauthorized:
                return "Unauthorized"
            case .notFound:
                return "Not found"
            }
        }
    }
}

struct Credentials: Codable {
    let login: String
    let password: String
}

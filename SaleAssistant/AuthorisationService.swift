//
//  AuthorisationService.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

final class AuthorisationService: RefreshTokenRetriever {
    
    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
    }
    
    private let url: URL
    private let client: HTTPClient
    private let decoder: JSONDecoder

    public init(url: URL,
                client: HTTPClient,
                decoder: JSONDecoder = JSONDecoder()) {
        self.url = url
        self.client = client
        self.decoder = decoder
    }
    
    func refreshToken() async throws -> String {
        let accessToken = try await authorize(with: Credentials(login: "", password: ""))
        return accessToken.value
    }

    
    func authorize(with credentials: Credentials) async throws -> AccessToken {
        var authRequest = URLRequest(url: url)
        authRequest.setValue("Basic \(base64Encoded(credentials))", forHTTPHeaderField: "Authorization")
        
        let payload: (data: Data, response: HTTPURLResponse)

        do {
            payload = try await client.perform(request: authRequest)
        } catch {
            throw Error.connectivity
        }

        guard payload.response.statusCode == 200 else {
            throw Error.invalidData
        }

        do {
            let accessToken = try decoder.decode(AccessToken.self, from: payload.data)
            return accessToken
        } catch {
            throw Error.invalidData
        }
    }

    private func base64Encoded(_ credentials: Credentials) -> String {
        Data("\(credentials.login):\(credentials.password)".utf8).base64EncodedString()
    }
}

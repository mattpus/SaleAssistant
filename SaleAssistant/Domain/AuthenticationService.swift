//
//  AuthenticationService.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

public final class AuthenticationService: RefreshTokenRetriever, Authenticating {
    
    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
    }
    
    private let url: URL
    private let client: HTTPClient
    private let decoder: JSONDecoder
    private let tokenSaver: TokenSaver
    
    public init(url: URL,
                client: HTTPClient,
                decoder: JSONDecoder = JSONDecoder(),
                tokenSaver: TokenSaver) {
        self.url = url
        self.client = client
        self.decoder = decoder
        self.tokenSaver = tokenSaver
    }
    
    public func refreshToken() async throws -> String {
        // TODO: we need credentials for the refresh tokens, we could store password and name or ask the user to provide the credentials otherwise we cant
        let accessToken = try await authenticate(with: Credentials(login: "", password: ""))
        return accessToken.value
    }
    
    public func authenticate(with credentials: Credentials) async throws -> AccessToken {
        let request = try makeAuthorizationRequest(with: credentials)
        let payload = try await send(request: request)
        let accessToken = try decodeAccessToken(from: payload.data)
        return try await persist(token: accessToken)
    }
    
    private func makeAuthorizationRequest(with credentials: Credentials) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
        let body = [
            "username": credentials.login,
            "password": credentials.password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw Error.invalidData
        }
        
        return request
    }
    
    private func send(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        do {
            let payload = try await client.perform(request: request)
            guard payload.response.statusCode == 200 else {
                throw Error.invalidData
            }
            return payload
        } catch let error as AuthenticationService.Error {
            throw error
        } catch {
            throw Error.connectivity
        }
    }
    
    private func decodeAccessToken(from data: Data) throws -> AccessToken {
        do {
            let result = try decoder.decode(AccessTokenDTO.self, from: data)
            return result.model
        } catch {
            throw Error.invalidData
        }
    }
    
    private func persist(token: AccessToken) async throws -> AccessToken {
        switch await tokenSaver.save(token: token) {
        case .success:
            return token
        case .failure(let error):
            throw error
        }
    }
}

private struct AccessTokenDTO: Decodable {
    let accessToken: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decode(String.self, forKey: .accessToken)
    }
    
    var model: AccessToken {
        AccessToken(value: accessToken, expirationDate: Date().addingTimeInterval(120))
    }
}

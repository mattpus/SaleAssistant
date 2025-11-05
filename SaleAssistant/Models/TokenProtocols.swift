//
//  TokenProtocols.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

public protocol TokenProvider: AnyObject {
    func getToken() async throws -> String
}

public protocol RefreshTokenRetriever: AnyObject {
    func refreshToken() async throws -> String
}

public protocol TokenSaver: AnyObject {
     func save(token: AccessToken) async -> Result<Void, Swift.Error>
}

public protocol TokenLoader: AnyObject {
    func load() async -> Result<AccessToken, Swift.Error>
}

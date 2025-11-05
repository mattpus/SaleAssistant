//
//  TokenService.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Foundation

public final class TokenService: TokenProvider {
    private let tokenLoader: TokenLoader
    private let refreshTokenRetriever: RefreshTokenRetriever

    public init(tokenLoader: TokenLoader, refreshTokenRetriever: RefreshTokenRetriever) {
        self.tokenLoader = tokenLoader
        self.refreshTokenRetriever = refreshTokenRetriever
    }

    public func getToken() async throws -> String {
        let result = await tokenLoader.load()

        switch result {
        case .success(let accessToken):
            guard accessToken.isValid else {
                let newAccessToken = try await refreshTokenRetriever.refreshToken()
                return newAccessToken
            }
            return accessToken.value
        case .failure(let error):
            throw error
        }
    }
}

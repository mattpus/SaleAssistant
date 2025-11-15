//
//  TokenService.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Foundation

public final class TokenService: TokenProvider {
    
    public enum Error: Swift.Error, Equatable {
        case invalidToken
        case failedRetrievingToken
        
        var message: String {
            switch self {
            case .invalidToken: return "The token is invalid"
            case .failedRetrievingToken: return "We failed retrieve token. Please try again."
            }
        }
    }
    
    private let tokenLoader: TokenLoader

    public init(tokenLoader: TokenLoader) {
        self.tokenLoader = tokenLoader
    }

    public func getToken() async throws -> String {
        let result = await tokenLoader.load()

        switch result {
        case .success(let accessToken):
            guard accessToken.isValid else {
                throw Error.invalidToken
            }
            return accessToken.value
        case .failure:
            throw Error.failedRetrievingToken
        }
    }
}

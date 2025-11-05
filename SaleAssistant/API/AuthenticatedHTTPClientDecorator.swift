//
//  AuthenticationHTTPClientDecorator.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

public final class AuthenticatedHTTPClientDecorator: HTTPClient {
    private let docoratee: HTTPClient
    private let tokenProvider: TokenProvider

    public init(docoratee: HTTPClient, tokenProvider: TokenProvider) {
        self.docoratee = docoratee
        self.tokenProvider = tokenProvider
    }

    public func perform(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        let token = try await tokenProvider.getToken()
        var authenticatedRequest = request
        authenticatedRequest.setValue(token, forHTTPHeaderField: "Authorization")
        return try await docoratee.perform(request: authenticatedRequest)
    }
}

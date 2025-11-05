//
//  AuthenticationHTTPClientDecorator.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

final class AuthenticatedHTTPClientDecorator: HTTPClient {
    private let docoratee: HTTPClient
    private let tokenProvider: TokenProvider
    
    init(docoratee: HTTPClient, tokenProvider: TokenProvider) {
        self.docoratee = docoratee
        self.tokenProvider = tokenProvider
    }
    
    func perform(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
       try await docoratee.perform(request: request)
    }
}

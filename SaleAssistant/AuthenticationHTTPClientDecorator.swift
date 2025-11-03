//
//  AuthenticationHTTPClientDecorator.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

final class AuthenticationHTTPClientDecorator: HTTPClient {
    private let docoratee: HTTPClient
    private let tokenService: GetTokenService
    
    init(docoratee: HTTPClient, tokenService: GetTokenService) {
        self.docoratee = docoratee
        self.tokenService = tokenService
    }
    
    func get(from url: URL) async throws -> (data: Data, response: HTTPURLResponse) {
       try await docoratee.get(from: url)
    }
}

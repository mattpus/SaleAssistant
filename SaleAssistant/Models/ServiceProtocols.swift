//
//  ServiceProtocols.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

protocol Authenticating {
    func authenticate(with credentials: Credentials) async throws -> AccessToken
}

protocol ProductsLoading {
    func loadProducts() async throws -> [Product]
}

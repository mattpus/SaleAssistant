//
//  ServiceProtocols.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Foundation

public protocol Authenticating {
    func authenticate(with credentials: Credentials) async throws -> AccessToken
}

public protocol ProductsLoading {
    func loadProducts() async throws -> [Product]
}

public protocol SalesLoading {
    func loadSales() async throws -> [Sale]
}

public protocol RatesLoading {
    func loadRates() async throws -> [String: Decimal]
}

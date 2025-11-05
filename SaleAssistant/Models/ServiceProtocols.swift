//
//  ServiceProtocols.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Foundation

protocol Authenticating {
    func authenticate(with credentials: Credentials) async throws -> AccessToken
}

protocol ProductsLoading {
    func loadProducts() async throws -> [Product]
}

protocol SalesLoading {
    func loadSales() async throws -> [Sale]
}

protocol RatesLoading {
    func loadRates() async throws -> [String: Decimal]
}

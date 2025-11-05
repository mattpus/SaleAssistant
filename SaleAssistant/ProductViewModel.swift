//
//  ProductViewModel.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Combine
import Foundation

@MainActor
final class ProductViewModel: ObservableObject {
    struct Item: Equatable, Identifiable {
        let id: String
        let name: String
        let salesCount: Int
    }

    @Published private(set) var isLoading = false
    @Published private(set) var items: [Item] = []
    @Published private(set) var error: Swift.Error?
    @Published private(set) var sessionExpired = false

    private let productsLoader: ProductsLoading
    private let salesLoader: SalesLoading

    init(productsLoader: ProductsLoading,
         salesLoader: SalesLoading) {
        self.productsLoader = productsLoader
        self.salesLoader = salesLoader
    }

    convenience init(productsURL: URL,
                     salesURL: URL,
                     client: HTTPClient,
                     tokenProvider: TokenProvider,
                     decoder: JSONDecoder = JSONDecoder()) {
        let authenticatedClient = AuthenticatedHTTPClientDecorator(docoratee: client, tokenProvider: tokenProvider)
        let productsService = ProductsService(url: productsURL, client: authenticatedClient, decoder: decoder)
        let salesService = SalesService(url: salesURL, client: authenticatedClient, decoder: decoder)
        self.init(productsLoader: productsService, salesLoader: salesService)
    }

    func load() async {
        isLoading = true
        error = nil
        sessionExpired = false

        defer { isLoading = false }

        do {
            async let productsTask = productsLoader.loadProducts()
            async let salesTask = salesLoader.loadSales()

            let products = try await productsTask
            let sales = try await salesTask
            items = makeItems(products: products, sales: sales)
        } catch {
            items = []
            handle(error: error)
        }
    }

    private func makeItems(products: [Product], sales: [Sale]) -> [Item] {
        let counts = sales.reduce(into: [String: Int]()) { partialResult, sale in
            partialResult[sale.productID, default: 0] += 1
        }

        return products.map { product in
            Item(id: product.id,
                 name: product.name,
                 salesCount: counts[product.id] ?? 0)
        }
    }

    private func handle(error: Swift.Error) {
        if isUnauthorized(error) {
            sessionExpired = true
        }
        self.error = error
    }

    private func isUnauthorized(_ error: Swift.Error) -> Bool {
        if let productsError = error as? ProductsService.Error, productsError == .unauthorized {
            return true
        }

        if let salesError = error as? SalesService.Error, salesError == .unauthorized {
            return true
        }

        return false
    }
}

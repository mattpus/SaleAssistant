//
//  ProductViewModel.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Combine
import Foundation

@MainActor
public final class ProductViewModel: ObservableObject {
    public struct Item: Equatable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let salesCount: Int

        public init(id: String, name: String, salesCount: Int) {
            self.id = id
            self.name = name
            self.salesCount = salesCount
        }
    }

    @Published public private(set) var isLoading = false
    @Published public private(set) var items: [Item] = []
    @Published public private(set) var error: Swift.Error?
    @Published public private(set) var sessionExpired = false

    private let productsLoader: ProductsLoading
    private let salesLoader: SalesLoading

    public init(productsLoader: ProductsLoading,
                salesLoader: SalesLoading) {
        self.productsLoader = productsLoader
        self.salesLoader = salesLoader
    }

    public convenience init(productsURL: URL,
                            salesURL: URL,
                            client: HTTPClient,
                            tokenProvider: TokenProvider,
                            decoder: JSONDecoder = JSONDecoder()) {
        let authenticatedClient = AuthenticatedHTTPClientDecorator(docoratee: client, tokenProvider: tokenProvider)
        let productsService = ProductsService(url: productsURL, client: authenticatedClient, decoder: decoder)
        let salesService = SalesService(url: salesURL, client: authenticatedClient, decoder: decoder)
        self.init(productsLoader: productsService, salesLoader: salesService)
    }

    public func load() async {
        isLoading = true
        error = nil
        sessionExpired = false

        defer { isLoading = false }

        do {
            let products = try await productsLoader.loadProducts()
            let sales = try await salesLoader.loadSales()
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

        return products
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map { product in
                Item(id: product.id,
                     name: product.name,
                     salesCount: counts[product.id] ?? 0)
            }
    }

    private func handle(error: Swift.Error) {
        if isUnauthorized(error) {
            sessionExpired = true
        }
        self.error = makeUserFacingError(from: error)
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
    
    private func makeUserFacingError(from error: Swift.Error) -> Error {
        if let productsError = error as? ProductsService.Error {
            return UserFacingError(message: productsError.message)
        }

        if let salesError = error as? SalesService.Error {
            return UserFacingError(message: salesError.message)
        }

        return UserFacingError(message: "Something went wrong. Please try again.")
    }
}

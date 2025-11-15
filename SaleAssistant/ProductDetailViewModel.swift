//
//  ProductDetailViewModel.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Combine
import Foundation

@MainActor
public final class ProductDetailViewModel: ObservableObject {
    public struct SaleItem: Identifiable, Equatable {
        public let id: String
        public let originalAmount: Decimal
        public let originalCurrency: String
        public let usdAmount: Decimal
        public let date: Date

        public init(id: String, originalAmount: Decimal, originalCurrency: String, usdAmount: Decimal, date: Date) {
            self.id = id
            self.originalAmount = originalAmount
            self.originalCurrency = originalCurrency
            self.usdAmount = usdAmount
            self.date = date
        }
    }

    public enum ConversionError: Swift.Error, Equatable {
        case missingRate(currency: String)
        
        var message: String {
            switch self {
            case .missingRate(currency: let currency):
                return "No rate available for \(currency)"
            }
        }
    }

    @Published public private(set) var productName: String
    @Published public private(set) var isLoading = false
    @Published public private(set) var saleItems: [SaleItem] = []
    @Published public private(set) var salesCount: Int = 0
    @Published public private(set) var totalSalesUSD: Decimal = .zero
    @Published public private(set) var error: Swift.Error?
    @Published public private(set) var sessionExpired = false

    private let product: Product
    private let salesLoader: SalesLoading
    private let ratesLoader: RatesLoading
    private var pendingReload = false

    public init(product: Product,
                salesLoader: SalesLoading,
                ratesLoader: RatesLoading) {
        self.product = product
        self.salesLoader = salesLoader
        self.ratesLoader = ratesLoader
        self.productName = product.name
    }

    public convenience init(product: Product,
                            salesURL: URL,
                            ratesURL: URL,
                            client: HTTPClient,
                            tokenProvider: TokenProvider,
                            decoder: JSONDecoder = JSONDecoder()) {
        let authenticatedClient = AuthenticatedHTTPClientDecorator(docoratee: client, tokenProvider: tokenProvider)
        let salesService = SalesService(url: salesURL, client: authenticatedClient, decoder: decoder)
        let ratesService = RatesService(url: ratesURL, client: client, decoder: decoder)
        self.init(product: product, salesLoader: salesService, ratesLoader: ratesService)
    }

    public func load() async {
        isLoading = true
        error = nil
        sessionExpired = false
        saleItems = []
        salesCount = 0
        totalSalesUSD = .zero

        defer { isLoading = false }

        do {
            let allSales = try await salesLoader.loadSales()
            let rates = try await ratesLoader.loadRates()

            let productSales = allSales.filter { $0.productID == product.id }
            let (items, totalUSD) = try makeItems(from: productSales, rates: rates)

            saleItems = items
            salesCount = items.count
            totalSalesUSD = totalUSD
        } catch {
            handle(error: error)
        }
    }

    private func makeItems(from sales: [Sale], rates: [String: Decimal]) throws -> ([SaleItem], Decimal) {
        var total: Decimal = .zero
        let items = try sales.enumerated().map { offset, sale -> SaleItem in
            let usdAmount = try convertToUSD(sale: sale, rates: rates)
            total += usdAmount
            return SaleItem(id: makeIdentifier(for: sale, offset: offset),
                            originalAmount: sale.amount,
                            originalCurrency: sale.currencyCode.uppercased(),
                            usdAmount: usdAmount,
                            date: sale.date)
        }

        let sortedItems = items.sorted { $0.date > $1.date }
        return (sortedItems, total)
    }

    private func convertToUSD(sale: Sale, rates: [String: Decimal]) throws -> Decimal {
        let currency = sale.currencyCode.uppercased()

        if currency == "USD" {
            return sale.amount
        }

        if let rate = rates[currency] {
            return sale.amount * rate
        }

        throw ConversionError.missingRate(currency: currency)
    }

    private func makeIdentifier(for sale: Sale, offset: Int) -> String {
        "\(sale.productID)-\(sale.date.timeIntervalSince1970)-\(offset)"
    }

    private func handle(error: Swift.Error) {
        if isUnauthorized(error) {
            sessionExpired = true
        }
        self.error = makeUserFacingError(from: error)
    }

    private func isUnauthorized(_ error: Swift.Error) -> Bool {
        if let salesError = error as? SalesService.Error, salesError == .unauthorized {
            return true
        }

        if let ratesError = error as? RatesService.Error, ratesError == .unauthorized {
            return true
        }

        return false
    }
    
    private func makeUserFacingError(from error: Swift.Error) -> Error {
        if let conversionError = error as? ConversionError {
            return UserFacingError(message: conversionError.message)
        }
        
        if let salesError = error as? SalesService.Error {
            return UserFacingError(message: salesError.message)
        }

        if let ratesError = error as? RatesService.Error {
            return UserFacingError(message: ratesError.message)
        }
    
        return UserFacingError(message: "Something went wrong. Please try again.")
    }
}

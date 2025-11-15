//
//  ProductDetailViewModelTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 05/11/2025.
//

import Foundation
import XCTest
@testable import SaleAssistant

@MainActor
final class ProductDetailViewModelTests: XCTestCase {
    func test_load_convertsSalesAndPublishesSummary() async throws {
        let product = Product(id: "product-1", name: "Product 1")
        let sales = [
            makeSale(productID: product.id, currency: "USD", amount: 100, daysAgo: 1),
            makeSale(productID: product.id, currency: "EUR", amount: 50, daysAgo: 2)
        ]
        let rates = makeRatesDictionary()
        let (sut, salesLoader, ratesLoader) = makeSUT(product: product,
                                                      salesResult: .success(sales),
                                                      ratesResult: .success(rates))

        await sut.load()

        XCTAssertEqual(salesLoader.loadCallCount, 1)
        XCTAssertEqual(ratesLoader.loadCallCount, 1)
        XCTAssertEqual(sut.salesCount, 2)
        let eurRate = rates["EUR"] ?? .zero
        XCTAssertEqual(sut.totalSalesUSD, Decimal(100) + Decimal(50) * eurRate)
        XCTAssertEqual(sut.saleItems.count, 2)
        XCTAssertEqual(sut.saleItems.first?.originalCurrency, "USD")
        XCTAssertEqual(sut.saleItems.first?.usdAmount, Decimal(100))
        XCTAssertEqual(sut.saleItems.last?.usdAmount, Decimal(50) * eurRate)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.sessionExpired)
    }

    func test_load_filtersSalesByProduct() async {
        let product = Product(id: "product-1", name: "Product 1")
        let sales = [
            makeSale(productID: product.id, currency: "USD", amount: 30, daysAgo: 1),
            makeSale(productID: "other", currency: "USD", amount: 20, daysAgo: 1)
        ]
        let rates = makeRatesDictionary()
        let (sut, _, _) = makeSUT(product: product,
                                  salesResult: .success(sales),
                                  ratesResult: .success(rates))

        await sut.load()

        XCTAssertEqual(sut.salesCount, 1)
        XCTAssertEqual(sut.totalSalesUSD, Decimal(30))
    }

    func test_load_setsErrorWhenRateMissing() async {
        let product = Product(id: "product-1", name: "Product 1")
        let sales = [
            makeSale(productID: product.id, currency: "JPY", amount: 1000, daysAgo: 1)
        ]
        var rates = makeRatesDictionary()
        rates.removeValue(forKey: "JPY")
        let (sut, _, _) = makeSUT(product: product,
                                  salesResult: .success(sales),
                                  ratesResult: .success(rates))

        await sut.load()

        XCTAssertEqual(sut.salesCount, 0)
        XCTAssertEqual(sut.totalSalesUSD, 0)
        XCTAssertEqual((sut.error as? UserFacingError)?.message, "No rate available for JPY")
    }

    func test_load_marksSessionExpiredWhenSalesLoaderReturnsUnauthorized() async {
        let product = Product(id: "product-1", name: "Product 1")
        let (sut, _, _) = makeSUT(product: product,
                                  salesResult: .failure(SalesService.Error.unauthorized),
                                  ratesResult: .success([:]))

        await sut.load()

        XCTAssertTrue(sut.sessionExpired)
        XCTAssertNotNil(sut.error)
    }

    func test_load_marksSessionExpiredWhenRatesLoaderReturnsUnauthorized() async {
        let product = Product(id: "product-1", name: "Product 1")
        let (sut, _, _) = makeSUT(product: product,
                                  salesResult: .success([]),
                                  ratesResult: .failure(RatesService.Error.unauthorized))

        await sut.load()

        XCTAssertTrue(sut.sessionExpired)
        XCTAssertNotNil(sut.error)
    }

    // MARK: - Helpers

    private func makeSUT(product: Product,
                         salesResult: Result<[Sale], Error>,
                         ratesResult: Result<[String: Decimal], Error>,
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (ProductDetailViewModel, SalesLoaderStub, RatesLoaderStub) {
        let salesLoader = SalesLoaderStub(result: salesResult)
        let ratesLoader = RatesLoaderStub(result: ratesResult)
        let sut = ProductDetailViewModel(product: product,
                                         salesLoader: salesLoader,
                                         ratesLoader: ratesLoader)
        trackForMemoryLeaks(salesLoader, file: file, line: line)
        trackForMemoryLeaks(ratesLoader, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, salesLoader, ratesLoader)
    }

    private func makeSale(productID: String,
                          currency: String,
                          amount: Decimal,
                          daysAgo: Int,
                          file: StaticString = #filePath,
                          line: UInt = #line) -> Sale {
        guard let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: -daysAgo, to: Date()) else {
            XCTFail("Unable to create date", file: file, line: line)
            return Sale(productID: productID, currencyCode: currency, amount: amount, date: Date())
        }
        return Sale(productID: productID, currencyCode: currency, amount: amount, date: date)
    }

    private func makeRatesDictionary(file: StaticString = #filePath, line: UInt = #line) -> [String: Decimal] {
        let data = loadFixture(named: "rates", file: file, line: line)
        do {
            let rates = try JSONDecoder().decode([RateFixture].self, from: data)
            var result: [String: Decimal] = [:]
            for rate in rates where rate.to.uppercased() == "USD" {
                result[rate.from.uppercased()] = rate.rate
            }
            return result
        } catch {
            XCTFail("Failed to decode rates: \(error)", file: file, line: line)
            return [:]
        }
    }

    private final class SalesLoaderStub: SalesLoading {
        private let result: Result<[Sale], Error>
        private(set) var loadCallCount = 0

        init(result: Result<[Sale], Error>) {
            self.result = result
        }

        func loadSales() async throws -> [Sale] {
            loadCallCount += 1
            switch result {
            case let .success(sales):
                return sales
            case let .failure(error):
                throw error
            }
        }
    }

    private final class RatesLoaderStub: RatesLoading {
        private let result: Result<[String: Decimal], Error>
        private(set) var loadCallCount = 0

        init(result: Result<[String: Decimal], Error>) {
            self.result = result
        }

        func loadRates() async throws -> [String: Decimal] {
            loadCallCount += 1
            switch result {
            case let .success(rates):
                return rates
            case let .failure(error):
                throw error
            }
        }
    }

    private struct RateFixture: Decodable {
        let from: String
        let to: String
        let rate: Decimal
    }
}

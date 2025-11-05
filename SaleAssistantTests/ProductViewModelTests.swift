//
//  ProductViewModelTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 05/11/2025.
//

import Foundation
import XCTest
@testable import SaleAssistant
import Synchronization

@MainActor
final class ProductViewModelTests: XCTestCase {
    func test_load_usesAuthenticatedHTTPClient() async throws {
        let productsURL = URL(string: "https://example.com/products")!
        let salesURL = URL(string: "https://example.com/sales")!
        let client = HTTPClientSpy()
        let tokenProvider = TokenProviderSpy(token: "access-token")

        client.stub(result: .success((makeProductsData(), anyHTTPResponse())), for: productsURL)
        client.stub(result: .success((makeSalesData(), anyHTTPResponse())), for: salesURL)

        let sut = ProductViewModel(productsURL: productsURL,
                                   salesURL: salesURL,
                                   client: client,
                                   tokenProvider: tokenProvider)

        await sut.load()

        XCTAssertEqual(client.requests.count, 2)
        XCTAssertTrue(client.requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "access-token" })
        XCTAssertGreaterThanOrEqual(tokenProvider.getTokenCallCount, 2)
    }

    func test_load_publishesProductsWithSalesCount() async throws {
        let productsURL = URL(string: "https://example.com/products")!
        let salesURL = URL(string: "https://example.com/sales")!
        let client = HTTPClientSpy()
        let tokenProvider = TokenProviderSpy(token: "token")

        let productsData = makeProductsData()
        let salesData = makeSalesData()
        client.stub(result: .success((productsData, anyHTTPResponse())), for: productsURL)
        client.stub(result: .success((salesData, anyHTTPResponse())), for: salesURL)

        let sut = ProductViewModel(productsURL: productsURL,
                                   salesURL: salesURL,
                                   client: client,
                                   tokenProvider: tokenProvider)

        await sut.load()

        let expectedCounts = try makeExpectedSalesCounts(productsData: productsData, salesData: salesData)
        XCTAssertEqual(sut.items.count, expectedCounts.count)
        for item in sut.items {
            XCTAssertEqual(item.salesCount, expectedCounts[item.id, default: 0])
        }
    }

    func test_load_marksSessionExpiredWhenUnauthorized() async {
        let productsLoader = ProductsLoaderStub(result: .failure(ProductsService.Error.unauthorized))
        let salesLoader = SalesLoaderStub(result: .success([]))
        let sut = ProductViewModel(productsLoader: productsLoader, salesLoader: salesLoader)

        await sut.load()

        XCTAssertTrue(sut.sessionExpired)
        XCTAssertEqual(sut.items.count, 0)
        XCTAssertNotNil(sut.error)
    }

    func test_load_setsErrorOnGeneralFailure() async {
        let expectedError = anyNSError()
        let productsLoader = ProductsLoaderStub(result: .failure(expectedError))
        let salesLoader = SalesLoaderStub(result: .success([]))
        let sut = ProductViewModel(productsLoader: productsLoader, salesLoader: salesLoader)

        await sut.load()

        XCTAssertFalse(sut.sessionExpired)
        XCTAssertEqual(sut.items.count, 0)
        XCTAssertEqual(sut.error as NSError?, expectedError)
    }

    // MARK: - Helpers

    private func makeExpectedSalesCounts(productsData: Data, salesData: Data) throws -> [String: Int] {
        let products = try JSONDecoder().decode([ProductFixture].self, from: productsData)
        let sales = try JSONDecoder().decode([SaleFixture].self, from: salesData)

        var counts: [String: Int] = [:]
        for product in products {
            counts[product.id] = 0
        }

        for sale in sales {
            counts[sale.productID, default: 0] += 1
        }

        return counts
    }

    private func makeProductsData() -> Data {
        loadFixture(named: "products")
    }

    private func makeSalesData() -> Data {
        loadFixture(named: "sales")
    }

    private struct ProductFixture: Decodable {
        let id: String
    }

    private struct SaleFixture: Decodable {
        let productID: String

        enum CodingKeys: String, CodingKey {
            case productID = "product_id"
        }
    }

    private final class TokenProviderSpy: TokenProvider {
        private let token: String
        private let callCountStorage = Mutex<Int>(0)

        init(token: String) {
            self.token = token
        }

        func getToken() async throws -> String {
            callCountStorage.withLock { count in
                count += 1
            }
            return token
        }

        var getTokenCallCount: Int {
            callCountStorage.withLock { $0 }
        }
    }

    private final class ProductsLoaderStub: ProductsLoading {
        private let result: Result<[Product], Error>

        init(result: Result<[Product], Error>) {
            self.result = result
        }

        func loadProducts() async throws -> [Product] {
            switch result {
            case let .success(products):
                return products
            case let .failure(error):
                throw error
            }
        }
    }

    private final class SalesLoaderStub: SalesLoading {
        private let result: Result<[Sale], Error>

        init(result: Result<[Sale], Error>) {
            self.result = result
        }

        func loadSales() async throws -> [Sale] {
            switch result {
            case let .success(sales):
                return sales
            case let .failure(error):
                throw error
            }
        }
    }
}

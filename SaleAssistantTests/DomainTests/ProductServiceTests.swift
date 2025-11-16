//
//  ProductServiceTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 16/11/2025.
//

import XCTest
@testable import SaleAssistant

@MainActor
final class ProductServiceTests: XCTestCase {
    func test_loadProducts_requestsDataFromURL() async throws {
        let url = anyURL()
        let (sut, client) = makeSUT(url: url)
        client.stub(result: .success((makeProductsJSON(), anyHTTPResponse())))

        _ = try await sut.loadProducts()

        XCTAssertEqual(client.requestedURLs, [url])
    }

    func test_loadProducts_deliversProductsOn200ResponseWithValidJSON() async throws {
        let expectedProducts = [
            Product(id: "1", name: "Mac"),
            Product(id: "2", name: "Vision Pro")
        ]
        let (sut, client) = makeSUT()
        client.stub(result: .success((makeProductsJSON(from: expectedProducts), anyHTTPResponse())))

        let receivedProducts = try await sut.loadProducts()

        XCTAssertEqual(receivedProducts.map(\.id), expectedProducts.map(\.id))
        XCTAssertEqual(receivedProducts.map(\.name), expectedProducts.map(\.name))
    }

    func test_loadProducts_throwsConnectivityErrorOnClientFailure() async {
        let (sut, client) = makeSUT()
        client.stub(result: .failure(anyNSError()))

        await expect(sut, toThrow: .connectivity)
    }

    func test_loadProducts_throwsUnauthorizedOn401Response() async {
        let (sut, client) = makeSUT()
        client.stub(result: .success((Data(), anyHTTPResponse(statusCode: 401))))

        await expect(sut, toThrow: .unauthorized)
    }

    func test_loadProducts_throwsInvalidDataOnNon200Response() async {
        let (sut, client) = makeSUT()
        client.stub(result: .success((Data(), anyHTTPResponse(statusCode: 500))))

        await expect(sut, toThrow: .invalidData)
    }

    func test_loadProducts_throwsInvalidDataOnInvalidJSON() async {
        let (sut, client) = makeSUT()
        client.stub(result: .success((Data("invalid".utf8), anyHTTPResponse())))

        await expect(sut, toThrow: .invalidData)
    }

    // MARK: - Helpers

    private func makeSUT(url: URL = anyURL(),
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (ProductsService, HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = ProductsService(url: url, client: client)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client)
    }

    private func makeProductsJSON(from products: [Product] = [
        Product(id: "1", name: "Mac"),
        Product(id: "2", name: "Vision Pro")
    ]) -> Data {
        let jsonArray = products.map { ["id": $0.id, "name": $0.name] }
        return try! JSONSerialization.data(withJSONObject: jsonArray)
    }

    private func expect(_ sut: ProductsService,
                        toThrow expectedError: ProductsService.Error,
                        file: StaticString = #filePath,
                        line: UInt = #line) async {
        do {
            _ = try await sut.loadProducts()
            XCTFail("Expected to throw \(expectedError), got success instead", file: file, line: line)
        } catch let receivedError as ProductsService.Error {
            XCTAssertEqual(receivedError, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected ProductsService.Error, got \(error)", file: file, line: line)
        }
    }
}

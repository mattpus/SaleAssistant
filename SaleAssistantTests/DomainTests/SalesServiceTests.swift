//
//  SalesServiceTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 16/11/2025.
//

import XCTest
@testable import SaleAssistant

@MainActor
final class SalesServiceTests: XCTestCase {
    func test_loadSales_requestsDataFromURL() async throws {
        let url = anyURL()
        let (sut, client) = makeSUT(url: url)
        client.stub(result: .success((makeSalesJSON(), anyHTTPResponse())))

        _ = try await sut.loadSales()

        XCTAssertEqual(client.requestedURLs, [url])
    }

    func test_loadSales_deliversSalesOn200ResponseWithValidJSON() async throws {
        let expectedDate = Formatters.iso8601Formatter.date(from: "2024-09-10T12:34:56.123Z")!
        let expectedAmount = Decimal(string: "199.99")!
        let (sut, client) = makeSUT()
        client.stub(result: .success((makeSalesJSON(date: "2024-09-10T12:34:56.123Z",
                                                    amount: "199.99",
                                                    productID: "product-123",
                                                    currencyCode: "USD"),
                                      anyHTTPResponse())))

        let sales = try await sut.loadSales()

        XCTAssertEqual(sales.count, 1)
        XCTAssertEqual(sales.first?.productID, "product-123")
        XCTAssertEqual(sales.first?.currencyCode, "USD")
        XCTAssertEqual(sales.first?.amount, expectedAmount)
        XCTAssertEqual(sales.first?.date, expectedDate)
    }

    func test_loadSales_throwsConnectivityErrorOnClientFailure() async {
        let (sut, client) = makeSUT()
        client.stub(result: .failure(anyNSError()))

        await expect(sut, toThrow: .connectivity)
    }

    func test_loadSales_throwsUnauthorizedOn401Response() async {
        let (sut, client) = makeSUT()
        client.stub(result: .success((Data(), anyHTTPResponse(statusCode: 401))))

        await expect(sut, toThrow: .unauthorized)
    }

    func test_loadSales_throwsUnauthorizedWhenTokenErrorHappens() async {
        let (sut, client) = makeSUT()
        client.stub(result: .failure(TokenService.Error.invalidToken))

        await expect(sut, toThrow: .unauthorized)
    }

    func test_loadSales_throwsInvalidDataOnNon200Response() async {
        let (sut, client) = makeSUT()
        client.stub(result: .success((Data(), anyHTTPResponse(statusCode: 503))))

        await expect(sut, toThrow: .invalidData)
    }

    func test_loadSales_throwsInvalidDataOnInvalidJSON() async {
        let (sut, client) = makeSUT()
        client.stub(result: .success((Data("invalid".utf8), anyHTTPResponse())))

        await expect(sut, toThrow: .invalidData)
    }

    // MARK: - Helpers

    private func makeSUT(url: URL = anyURL(),
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (SalesService, HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = SalesService(url: url, client: client)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client)
    }

    private func makeSalesJSON(date: String = "2024-09-10T12:34:56.123Z",
                               amount: String = "199.99",
                               productID: String = "product-123",
                               currencyCode: String = "USD") -> Data {
        let json: [[String: Any]] = [[
            "product_id": productID,
            "currency_code": currencyCode,
            "amount": amount,
            "date": date
        ]]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    private func expect(_ sut: SalesService,
                        toThrow expectedError: SalesService.Error,
                        file: StaticString = #filePath,
                        line: UInt = #line) async {
        do {
            _ = try await sut.loadSales()
            XCTFail("Expected to throw \(expectedError), got success instead", file: file, line: line)
        } catch let receivedError as SalesService.Error {
            XCTAssertEqual(receivedError, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected SalesService.Error, got \(error)", file: file, line: line)
        }
    }
}

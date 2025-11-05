//
//  RatesServiceTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 05/11/2025.
//

import XCTest
@testable import SaleAssistant

@MainActor
final class RatesServiceTests: XCTestCase {
    func test_load_requestsDataFromURLWithoutAuthorizationHeader() async throws {
        let url = anyURL()
        let (sut, client) = makeSUT(url: url)
        client.stub(result: .success((makeRatesData(), anyHTTPResponse())))

        _ = try await sut.loadRates()

        XCTAssertEqual(client.requestedURLs, [url])
        XCTAssertNil(client.requests.first?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_load_deliversParsedRatesOn200Response() async throws {
        let data = makeRatesData()
        let (sut, client) = makeSUT()
        client.stub(result: .success((data, anyHTTPResponse())))

        let rates = try await sut.loadRates()

        XCTAssertEqual(rates["AUD"], Decimal(string: "0.5955216769890423")!)
        XCTAssertEqual(rates["EUR"], Decimal(string: "1.18")!)
    }

    func test_load_throwsInvalidDataOnNon200Response() async {
        let (sut, client) = makeSUT()
        client.stub(result: .success((Data(), anyHTTPResponse(statusCode: 400))))

        do {
            _ = try await sut.loadRates()
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as? RatesService.Error, .invalidData)
        }
    }

    func test_load_throwsConnectivityOnClientError() async {
        let (sut, client) = makeSUT()
        client.stub(result: .failure(anyNSError()))

        do {
            _ = try await sut.loadRates()
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as? RatesService.Error, .connectivity)
        }
    }

    func test_load_throwsInvalidDataOnMalformedJSON() async {
        let (sut, client) = makeSUT()
        client.stub(result: .success((Data("invalid".utf8), anyHTTPResponse())))

        do {
            _ = try await sut.loadRates()
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as? RatesService.Error, .invalidData)
        }
    }

    func test_load_throwsInvalidDataWhenNoUSDRates() async {
        let payload = """
        [
            { "from": "EUR", "to": "GBP", "rate": 0.85 }
        ]
        """.data(using: .utf8)!
        let (sut, client) = makeSUT()
        client.stub(result: .success((payload, anyHTTPResponse())))

        do {
            _ = try await sut.loadRates()
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as? RatesService.Error, .invalidData)
        }
    }

    // MARK: - Helpers

    private func makeSUT(url: URL = anyURL(),
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (RatesService, HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RatesService(url: url, client: client)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client)
    }

    private func makeRatesData() -> Data {
        loadFixture(named: "rates", withExtension: "json")
    }
}

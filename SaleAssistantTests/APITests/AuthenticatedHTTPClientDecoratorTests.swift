//
//  AuthenticatedHTTPClientDecoratorTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 05/11/2025.
//

import XCTest
@testable import SaleAssistant

@MainActor
final class AuthenticatedHTTPClientDecoratorTests: XCTestCase {
    func test_perform_addsAuthorizationHeader() async throws {
        let request = URLRequest(url: anyURL())
        let token = "access-token"
        let (sut, client, tokenProvider) = makeSUT(tokenResult: .success(token))
        client.stub(result: .success((anyData(), anyHTTPResponse())))

        _ = try await sut.perform(request: request)

        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "Authorization"), token)
        XCTAssertEqual(tokenProvider.receivedGetTokenCount, 1)
    }

    func test_perform_rethrowsTokenProviderError() async {
        let expectedError = anyNSError()
        let (sut, client, _) = makeSUT(tokenResult: .failure(expectedError))
        client.stub(result: .success((anyData(), anyHTTPResponse())))

        do {
            _ = try await sut.perform(request: URLRequest(url: anyURL()))
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as NSError, expectedError)
        }
    }

    func test_perform_forwardsClientError() async {
        let expectedError = anyNSError()
        let (sut, client, _) = makeSUT(tokenResult: .success("token"))
        client.stub(result: .failure(expectedError))

        do {
            _ = try await sut.perform(request: URLRequest(url: anyURL()))
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as NSError, expectedError)
        }
    }

    // MARK: - Helpers

    private func makeSUT(tokenResult: Result<String, NSError>,
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (AuthenticatedHTTPClientDecorator, HTTPClientSpy, TokenProviderSpy) {
        let client = HTTPClientSpy()
        let tokenProvider = TokenProviderSpy(result: tokenResult)
        let sut = AuthenticatedHTTPClientDecorator(docoratee: client, tokenProvider: tokenProvider)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(tokenProvider, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client, tokenProvider)
    }

    private final class TokenProviderSpy: TokenProvider {
        private let result: Result<String, NSError>
        private(set) var receivedGetTokenCount = 0

        init(result: Result<String, NSError>) {
            self.result = result
        }

        func getToken() async throws -> String {
            receivedGetTokenCount += 1
            switch result {
            case let .success(token):
                return token
            case let .failure(error):
                throw error
            }
        }
    }
}

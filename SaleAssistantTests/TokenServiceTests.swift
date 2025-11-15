//
//  TokenServiceTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 05/11/2025.
//

import XCTest
@testable import SaleAssistant

@MainActor
final class TokenServiceTests: XCTestCase {
    func test_getToken_deliversCachedTokenWhenValid() async throws {
        let token = AccessToken(value: "token", expirationDate: Date().addingTimeInterval(3600))
        let loader = TokenLoaderStub(result: .success(token))
        let sut = makeSUT(loader: loader)

        let receivedToken = try await sut.getToken()

        XCTAssertEqual(receivedToken, token.value)
    }

    func test_getToken_rethrowsLoaderError() async {
        let loader = TokenLoaderStub(result: .failure(anyNSError()))
        let sut = makeSUT(loader: loader)

        do {
            _ = try await sut.getToken()
            XCTFail("Expected to throw, got success instead")
        } catch let error as TokenService.Error {
            XCTAssertEqual(error, .failedRetrievingToken)
        } catch {
            XCTFail("Expected TokenService.Error.failedRetrievingToken, got \(error)")
        }
    }

    func test_getToken_propagatesRefreshError() async {
        let expiredToken = AccessToken(value: "expired", expirationDate: Date().addingTimeInterval(-10))
        let loader = TokenLoaderStub(result: .success(expiredToken))
        let sut = makeSUT(loader: loader)

        do {
            _ = try await sut.getToken()
            XCTFail("Expected to throw, got success instead")
        } catch let error as TokenService.Error {
            XCTAssertEqual(error, .invalidToken)
        } catch {
            XCTFail("Expected TokenService.Error.invalidToken, got \(error)")
        }
    }

    // MARK: - Helpers

    private func makeSUT(loader: TokenLoader,
                         file: StaticString = #filePath,
                         line: UInt = #line) -> TokenService {
        let sut = TokenService(tokenLoader: loader)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(loader as AnyObject, file: file, line: line)
        return sut
    }

    private final class TokenLoaderStub: TokenLoader {
        private let result: Result<AccessToken, Swift.Error>

        init(result: Result<AccessToken, Swift.Error>) {
            self.result = result
        }

        func load() async -> Result<AccessToken, Swift.Error> {
            result
        }
    }
}

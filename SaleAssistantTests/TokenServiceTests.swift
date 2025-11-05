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
        let refreshSpy = RefreshTokenRetrieverSpy()
        let sut = makeSUT(loader: loader, refreshTokenRetriever: refreshSpy)

        let receivedToken = try await sut.getToken()

        XCTAssertEqual(receivedToken, token.value)
        XCTAssertEqual(refreshSpy.refreshCallCount, 0)
    }

    func test_getToken_refreshesTokenWhenCachedTokenIsExpired() async throws {
        let expiredToken = AccessToken(value: "expired", expirationDate: Date().addingTimeInterval(-10))
        let loader = TokenLoaderStub(result: .success(expiredToken))
        let refreshSpy = RefreshTokenRetrieverSpy(result: .success("new-token"))
        let sut = makeSUT(loader: loader, refreshTokenRetriever: refreshSpy)

        let receivedToken = try await sut.getToken()

        XCTAssertEqual(receivedToken, "new-token")
        XCTAssertEqual(refreshSpy.refreshCallCount, 1)
    }

    func test_getToken_rethrowsLoaderError() async {
        let expectedError = anyNSError()
        let loader = TokenLoaderStub(result: .failure(expectedError))
        let refreshSpy = RefreshTokenRetrieverSpy()
        let sut = makeSUT(loader: loader, refreshTokenRetriever: refreshSpy)

        do {
            _ = try await sut.getToken()
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as NSError, expectedError)
        }
    }

    func test_getToken_propagatesRefreshError() async {
        let expiredToken = AccessToken(value: "expired", expirationDate: Date().addingTimeInterval(-10))
        let loader = TokenLoaderStub(result: .success(expiredToken))
        let expectedError = anyNSError()
        let refreshSpy = RefreshTokenRetrieverSpy(result: .failure(expectedError))
        let sut = makeSUT(loader: loader, refreshTokenRetriever: refreshSpy)

        do {
            _ = try await sut.getToken()
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as NSError, expectedError)
        }
        XCTAssertEqual(refreshSpy.refreshCallCount, 1)
    }

    // MARK: - Helpers

    private func makeSUT(loader: TokenLoader,
                         refreshTokenRetriever: RefreshTokenRetriever,
                         file: StaticString = #filePath,
                         line: UInt = #line) -> TokenService {
        let sut = TokenService(tokenLoader: loader, refreshTokenRetriever: refreshTokenRetriever)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(loader as AnyObject, file: file, line: line)
        trackForMemoryLeaks(refreshTokenRetriever as AnyObject, file: file, line: line)
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

    private final class RefreshTokenRetrieverSpy: RefreshTokenRetriever {
        private let result: Result<String, NSError>
        private(set) var refreshCallCount = 0

        init(result: Result<String, NSError> = .success("unused-token")) {
            self.result = result
        }

        func refreshToken() async throws -> String {
            refreshCallCount += 1
            switch result {
            case let .success(token):
                return token
            case let .failure(error):
                throw error
            }
        }
    }
}

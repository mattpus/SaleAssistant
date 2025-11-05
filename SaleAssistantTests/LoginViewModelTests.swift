//
//  LoginViewModelTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 05/11/2025.
//

import Foundation
import XCTest
@testable import SaleAssistant

@MainActor
final class LoginViewModelTests: XCTestCase {
    func test_login_requestsAuthorizationWithProvidedCredentials() async {
        let (sut, authenticator, _) = makeSUT()

        await sut.login(username: "user", password: "pass")

        XCTAssertEqual(authenticator.receivedCredentials?.login, "user")
        XCTAssertEqual(authenticator.receivedCredentials?.password, "pass")
    }

    func test_login_requestsProductsAfterSuccessfulAuthorization() async {
        let (sut, _, productsLoader) = makeSUT()

        await sut.login(username: "user", password: "pass")

        XCTAssertEqual(productsLoader.loadCallCount, 1)
    }

    func test_login_doesNotRequestProductsWhenAuthorizationFails() async {
        let (sut, authenticator, productsLoader) = makeSUT(authResult: .failure(anyNSError()))

        await sut.login(username: "user", password: "pass")

        XCTAssertEqual(productsLoader.loadCallCount, 0)
        XCTAssertEqual(authenticator.receivedCredentials?.login, "user")
    }

    func test_login_deliversLoadedProductsOnSuccess() async {
        let expectedProducts = [
            Product(id: "1", name: "Product 1"),
            Product(id: "2", name: "Product 2")
        ]
        let (sut, _, _) = makeSUT(productsResult: .success(expectedProducts))

        await sut.login(username: "user", password: "pass")

        XCTAssertEqual(sut.products.map(\.id), expectedProducts.map(\.id))
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
    }

    func test_login_setsErrorWhenAuthorizationFails() async {
        let expectedError = anyNSError()
        let (sut, _, _) = makeSUT(authResult: .failure(expectedError))

        await sut.login(username: "user", password: "pass")

        XCTAssertEqual(sut.products.count, 0)
        XCTAssertEqual(sut.error as NSError?, expectedError)
        XCTAssertFalse(sut.isLoading)
    }

    func test_login_setsErrorWhenLoadingProductsFails() async {
        let expectedError = anyNSError()
        let (sut, _, productsLoader) = makeSUT(productsResult: .failure(expectedError))

        await sut.login(username: "user", password: "pass")

        XCTAssertEqual(productsLoader.loadCallCount, 1)
        XCTAssertEqual(sut.products.count, 0)
        XCTAssertEqual(sut.error as NSError?, expectedError)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Helpers

    private func makeSUT(authResult: Result<AccessToken, NSError>? = nil,
                         productsResult: Result<[Product], NSError> = .success([]),
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (LoginViewModel, AuthenticatingSpy, ProductsLoadingSpy) {
        let authenticator = AuthenticatingSpy(result: authResult ?? .success(makeAccessToken()))
        let productsLoader = ProductsLoadingSpy(result: productsResult)
        let sut = LoginViewModel(authenticator: authenticator, productsLoader: productsLoader)
        trackForMemoryLeaks(authenticator, file: file, line: line)
        trackForMemoryLeaks(productsLoader, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, authenticator, productsLoader)
    }

    private func makeAccessToken(value: String = "token",
                                 expiration: Date = Date().addingTimeInterval(3600)) -> AccessToken {
        AccessToken(value: value, expirationDate: expiration)
    }

    private final class AuthenticatingSpy: Authenticating {
        private let result: Result<AccessToken, NSError>
        private(set) var receivedCredentials: Credentials?

        init(result: Result<AccessToken, NSError>) {
            self.result = result
        }

        func authenticate(with credentials: Credentials) async throws -> AccessToken {
            receivedCredentials = credentials
            switch result {
            case let .success(token):
                return token
            case let .failure(error):
                throw error
            }
        }
    }

    private final class ProductsLoadingSpy: ProductsLoading {
        private let result: Result<[Product], NSError>
        private(set) var loadCallCount = 0

        init(result: Result<[Product], NSError>) {
            self.result = result
        }

        func loadProducts() async throws -> [Product] {
            loadCallCount += 1
            switch result {
            case let .success(products):
                return products
            case let .failure(error):
                throw error
            }
        }
    }
}

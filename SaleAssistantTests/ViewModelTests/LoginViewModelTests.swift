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
        let (sut, authenticator) = makeSUT()

        _ = await sut.login(username: "user", password: "pass")

        XCTAssertEqual(authenticator.receivedCredentials?.login, "user")
        XCTAssertEqual(authenticator.receivedCredentials?.password, "pass")
    }
    
    func test_login_doesNotRequestProductsWhenAuthorizationFails() async {
        let (sut, authenticator) = makeSUT(authResult: .failure(anyNSError()))

        let success = await sut.login(username: "user", password: "pass")

        XCTAssertFalse(success)

        XCTAssertEqual(authenticator.receivedCredentials?.login, "user")
    }

    func test_login_setsErrorWhenAuthorizationFails() async {
        let (sut, _) = makeSUT(authResult: .failure(AuthenticationService.Error.invalidData))

        let success = await sut.login(username: "user", password: "pass")

        XCTAssertEqual(userFacingErrorMessage(from: sut), "We couldn't verify your username or password. Please try again.")
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(success)
    }

    func test_showSessionExpiredMessage_setsUserFacingError() {
        let (sut, _) = makeSUT()

        sut.showSessionExpiredMessage()

        XCTAssertEqual(userFacingErrorMessage(from: sut), "Your session has expired. Please log in again.")
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Helpers

    private func makeSUT(authResult: Result<AccessToken, Swift.Error>? = nil,
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (LoginViewModel, AuthenticatingSpy) {
        let authenticator = AuthenticatingSpy(result: authResult ?? .success(makeAccessToken()))
        let sut = LoginViewModel(authenticator: authenticator)
        trackForMemoryLeaks(authenticator, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, authenticator)
    }

    private func makeAccessToken(value: String = "token",
                                 expiration: Date = Date().addingTimeInterval(3600)) -> AccessToken {
        AccessToken(value: value, expirationDate: expiration)
    }

    private final class AuthenticatingSpy: Authenticating {
        private let result: Result<AccessToken, Swift.Error>
        private(set) var receivedCredentials: Credentials?

        init(result: Result<AccessToken, Swift.Error>) {
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

    private func userFacingErrorMessage(from sut: LoginViewModel) -> String? {
        (sut.error as? UserFacingError)?.message
    }
}

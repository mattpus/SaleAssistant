//
//  LoginViewModel.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Combine
import Foundation

@MainActor
public final class LoginViewModel: ObservableObject {
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: Error?

    private enum Constants {
        static let sessionExpiredMessage = "Your session has expired. Please log in again."
    }

    private let authenticator: Authenticating

    public init(authenticator: Authenticating) {
        self.authenticator = authenticator
    }

    @discardableResult
    public func login(username: String, password: String) async -> Bool {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            _ = try await authenticator.authenticate(with: Credentials(login: username, password: password))
            return true
        } catch {
            self.error = makeUserFacingError(from: error)
            return false
        }
    }

    public func showSessionExpiredMessage() {
        isLoading = false
        error = UserFacingError(message: Constants.sessionExpiredMessage)
    }

    private func makeUserFacingError(from error: Swift.Error) -> Error {
        if let authError = error as? AuthenticationService.Error {
            return UserFacingError(message: authError.message)
        }

        return UserFacingError(message: "Something went wrong. Please try again.")
    }
}

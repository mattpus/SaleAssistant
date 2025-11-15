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
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var error: Error?

    private let authenticator: Authenticating
    private let productsLoader: ProductsLoading

    public init(authenticator: Authenticating, productsLoader: ProductsLoading) {
        self.authenticator = authenticator
        self.productsLoader = productsLoader
    }

    @discardableResult
    public func login(username: String, password: String) async -> Bool {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            _ = try await authenticator.authenticate(with: Credentials(login: username, password: password))
            let loadedProducts = try await productsLoader.loadProducts()
            products = loadedProducts
            return true
        } catch {
            products = []
            self.error = makeUserFacingError(from: error)
            return false
        }
    }

    private func makeUserFacingError(from error: Swift.Error) -> Error {
        if let authError = error as? AuthenticationService.Error {
            return UserFacingError(message: authError.message)
        }

        if let productsError = error as? ProductsService.Error {
            return UserFacingError(message: productsError.message)
        }

        return UserFacingError(message: "Something went wrong. Please try again.")
    }
}

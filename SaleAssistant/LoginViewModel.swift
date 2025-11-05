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

    public func login(username: String, password: String) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            _ = try await authenticator.authenticate(with: Credentials(login: username, password: password))
            let loadedProducts = try await productsLoader.loadProducts()
            products = loadedProducts
        } catch {
            products = []
            self.error = error
        }
    }
}

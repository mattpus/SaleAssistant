//
//  LoginViewModel.swift
//  SaleAssistant
//
//  Created by OpenAI Assistant on 05/11/2025.
//

import Combine
import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var error: Error?

    private let authenticator: Authenticating
    private let productsLoader: ProductsLoading

    init(authenticator: Authenticating, productsLoader: ProductsLoading) {
        self.authenticator = authenticator
        self.productsLoader = productsLoader
    }

    func login(username: String, password: String) async {
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

//
//  Dependencies.swift
//  SaleAssistantiOSApp
//
//  Created by Matt on 05/11/2025.
//

import Foundation
import Combine
import SaleAssistant

@MainActor
final class Dependencies: ObservableObject {
    private let authenticationURL: URL
    private let productsURL: URL
    private let salesURL: URL
    private let ratesURL: URL
    private let baseClient: HTTPClient

    private lazy var decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private lazy var tokenStore = KeychainTokenStore()

    private lazy var authenticationService: AuthenticationService = {
        AuthenticationService(url: authenticationURL,
                              client: baseClient,
                              decoder: decoder,
                              tokenSaver: tokenStore)
    }()

    private lazy var tokenProvider: TokenProvider = {
        TokenService(tokenLoader: tokenStore,
                     refreshTokenRetriever: authenticationService)
    }()

    private lazy var authenticatedClient: HTTPClient = {
        AuthenticatedHTTPClientDecorator(docoratee: baseClient, tokenProvider: tokenProvider)
    }()

    private lazy var productsService: ProductsService = {
        ProductsService(url: productsURL, client: authenticatedClient, decoder: decoder)
    }()

    private lazy var salesService: SalesService = {
        SalesService(url: salesURL, client: authenticatedClient, decoder: decoder)
    }()

    private lazy var ratesService: RatesService = {
        RatesService(url: ratesURL, client: baseClient)
    }()

    lazy var loginViewModel: LoginViewModel = {
        LoginViewModel(authenticator: authenticationService,
                       productsLoader: productsService)
    }()

    lazy var productViewModel: ProductViewModel = {
        ProductViewModel(productsLoader: productsService,
                         salesLoader: salesService)
    }()

    init(client: HTTPClient = URLSessionHTTPClient(),
         authenticationURL: URL = URL(string: "https://ile-b2p4.essentialdeveloper.com/login")!,
         productsURL: URL = URL(string: "https://ile-b2p4.essentialdeveloper.com/products")!,
         salesURL: URL = URL(string: "https://ile-b2p4.essentialdeveloper.com/sales")!,
         ratesURL: URL = URL(string: "https://saleassistant.onrender.com/rates")!) {
        self.baseClient = client
        self.authenticationURL = authenticationURL
        self.productsURL = productsURL
        self.salesURL = salesURL
        self.ratesURL = ratesURL
    }

    func makeProductDetailViewModel(for product: Product) -> ProductDetailViewModel {
        ProductDetailViewModel(product: product,
                               salesLoader: salesService,
                               ratesLoader: ratesService)
    }

    func resetSession() {
        tokenStore.clear()
    }

    func hasValidStoredToken() async -> Bool {
        let result = await tokenStore.load()
        switch result {
        case .success(let token):
            return token.isValid
        case .failure:
            return false
        }
    }
}

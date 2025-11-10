//
//  SaleAssistantTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 10/11/2025.
//

import XCTest
import SaleAssistant
@testable import SaleAssistantiOSApp

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_init_startsInIdleRouteWithEmptyPath() async {
        let sut = makeSUT()

        XCTAssertEqual(sut.route, .idle)
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_showLogin_setsLoginRouteAndClearsPath() async {
        let sut = makeSUT()
        sut.path = [.product(anyItem())]

        sut.showLogin()

        XCTAssertEqual(sut.route, .login)
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_showProducts_setsProductsRouteAndClearsPath() async {
        let sut = makeSUT()
        sut.path = [.product(anyItem())]

        sut.showProducts()

        XCTAssertEqual(sut.route, .products)
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_showDetail_switchesToProductsRouteAndPushesDestination() async {
        let sut = makeSUT()
        sut.showLogin()
        let item = anyItem(id: "abc")

        sut.showDetail(for: item)

        XCTAssertEqual(sut.route, .products)
        XCTAssertEqual(sut.path, [.product(item)])
    }

    func test_logout_resetsSessionAndShowsLogin() async {
        let dependencies = CoordinatorDependenciesSpy()
        let sut = makeSUT(dependencies: dependencies)
        sut.showProducts()

        sut.logout()

        XCTAssertEqual(dependencies.resetSessionCallCount, 1)
        XCTAssertEqual(sut.route, .login)
    }

    func test_evaluateStoredToken_showsProductsWhenTokenIsValid() async {
        let dependencies = CoordinatorDependenciesSpy(hasValidStoredTokenResults: [true])
        let sut = makeSUT(dependencies: dependencies)

        await sut.evaluateStoredTokenIfNeeded()

        XCTAssertEqual(sut.route, .products)
    }

    func test_evaluateStoredToken_showsLoginWhenTokenIsMissing() async {
        let dependencies = CoordinatorDependenciesSpy(hasValidStoredTokenResults: [false])
        let sut = makeSUT(dependencies: dependencies)

        await sut.evaluateStoredTokenIfNeeded()

        XCTAssertEqual(sut.route, .login)
    }

    func test_evaluateStoredToken_runsOnlyOnceUntilReset() async {
        let dependencies = CoordinatorDependenciesSpy(hasValidStoredTokenResults: [true, false])
        let sut = makeSUT(dependencies: dependencies)

        await sut.evaluateStoredTokenIfNeeded()
        await sut.evaluateStoredTokenIfNeeded()

        XCTAssertEqual(dependencies.hasValidStoredTokenCallCount, 1)
        XCTAssertEqual(sut.route, .products)
    }

    func test_showLogin_allowsStoredTokenEvaluationToRunAgain() async {
        let dependencies = CoordinatorDependenciesSpy(hasValidStoredTokenResults: [true, false])
        let sut = makeSUT(dependencies: dependencies)

        await sut.evaluateStoredTokenIfNeeded()
        sut.showLogin()
        await sut.evaluateStoredTokenIfNeeded()

        XCTAssertEqual(dependencies.hasValidStoredTokenCallCount, 2)
        XCTAssertEqual(sut.route, .login)
    }

    // MARK: - Helpers

    private func makeSUT(dependencies: CoordinatorDependenciesSpy? = nil,
                         file: StaticString = #filePath,
                         line: UInt = #line) -> AppCoordinator {
        let resolvedDependencies = dependencies ?? CoordinatorDependenciesSpy()
        let sut = AppCoordinator(dependencies: resolvedDependencies)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(resolvedDependencies, file: file, line: line)
        return sut
    }

    private func anyItem(id: String = UUID().uuidString) -> ProductViewModel.Item {
        ProductViewModel.Item(id: id, name: "Any", salesCount: 0)
    }
}

// MARK: - Test doubles

@MainActor
private final class CoordinatorDependenciesSpy: AppCoordinatorDependencies {
    let loginViewModel: LoginViewModel
    let productViewModel: ProductViewModel

    private(set) var resetSessionCallCount = 0
    private(set) var hasValidStoredTokenCallCount = 0
    private var hasValidStoredTokenResults: [Bool]
    private let productDetailFactory: (Product) -> ProductDetailViewModel

    init(hasValidStoredTokenResults: [Bool] = []) {
        let authenticator = AuthenticatorStub()
        let productsLoader = ProductsLoaderStub()
        let salesLoader = SalesLoaderStub()
        let ratesLoader = RatesLoaderStub()

        self.loginViewModel = LoginViewModel(authenticator: authenticator, productsLoader: productsLoader)
        self.productViewModel = ProductViewModel(productsLoader: productsLoader, salesLoader: salesLoader)
        self.productDetailFactory = { product in
            ProductDetailViewModel(product: product,
                                   salesLoader: salesLoader,
                                   ratesLoader: ratesLoader)
        }
        self.hasValidStoredTokenResults = hasValidStoredTokenResults
    }

    func makeProductDetailViewModel(for product: Product) -> ProductDetailViewModel {
        productDetailFactory(product)
    }

    func resetSession() {
        resetSessionCallCount += 1
    }

    func hasValidStoredToken() async -> Bool {
        hasValidStoredTokenCallCount += 1
        if !hasValidStoredTokenResults.isEmpty {
            return hasValidStoredTokenResults.removeFirst()
        }
        return false
    }
}

private final class AuthenticatorStub: Authenticating {
    func authenticate(with credentials: Credentials) async throws -> AccessToken {
        AccessToken(value: "token", expirationDate: Date().addingTimeInterval(3600))
    }
}

private final class ProductsLoaderStub: ProductsLoading {
    func loadProducts() async throws -> [Product] { [] }
}

private final class SalesLoaderStub: SalesLoading {
    func loadSales() async throws -> [Sale] { [] }
}

private final class RatesLoaderStub: RatesLoading {
    func loadRates() async throws -> [String: Decimal] { [:] }
}

// MARK: - Leak tracking

@MainActor
private extension XCTestCase {
    func trackForMemoryLeaks(_ instance: AnyObject,
                             file: StaticString = #filePath,
                             line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}

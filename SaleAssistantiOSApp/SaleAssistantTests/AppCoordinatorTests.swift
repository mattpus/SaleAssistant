import XCTest
@testable import SaleAssistantiOSApp
@testable import SaleAssistant

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func test_init_startsInIdleRouteWithEmptyPath() async {
        let (sut, _) = makeSUT()

        XCTAssertEqual(sut.route, .idle)
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_showLogin_setsLoginRouteAndClearsPath() async {
        let (sut, _) = makeSUT()
        sut.path = [.product(anyItem())]

        sut.showLogin()

        XCTAssertEqual(sut.route, .login)
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_showProducts_setsProductsRouteAndClearsPath() async {
        let (sut, _) = makeSUT()
        sut.path = [.product(anyItem())]

        sut.showProducts()

        XCTAssertEqual(sut.route, .products)
        XCTAssertTrue(sut.path.isEmpty)
    }

    func test_showDetail_switchesToProductsRouteAndPushesDestination() async {
        let (sut, _) = makeSUT()
        sut.showLogin()
        let item = anyItem(id: "abc")

        sut.showDetail(for: item)

        XCTAssertEqual(sut.route, .products)
        XCTAssertEqual(sut.path, [.product(item)])
    }

    func test_logout_resetsSessionAndShowsLogin() async {
        let (sut, tokenStore) = makeSUT()
        sut.showProducts()

        sut.logout()

        XCTAssertEqual(tokenStore.clearCallCount, 1)
        XCTAssertEqual(sut.route, .login)
    }

    func test_evaluateStoredToken_showsProductsWhenTokenIsValid() async {
        let (sut, _) = makeSUT(hasValidStoredTokenResults: [true])

        await sut.evaluateStoredTokenIfNeeded()

        XCTAssertEqual(sut.route, .products)
    }

    func test_evaluateStoredToken_showsLoginWhenTokenIsMissing() async {
        let (sut, _) = makeSUT(hasValidStoredTokenResults: [false])

        await sut.evaluateStoredTokenIfNeeded()

        XCTAssertEqual(sut.route, .login)
    }

    func test_evaluateStoredToken_runsOnlyOnceUntilReset() async {
        let (sut, tokenStore) = makeSUT(hasValidStoredTokenResults: [true, false])

        await sut.evaluateStoredTokenIfNeeded()
        await sut.evaluateStoredTokenIfNeeded()

        XCTAssertEqual(tokenStore.loadCallCount, 1)
        XCTAssertEqual(sut.route, .products)
    }

    func test_showLogin_allowsStoredTokenEvaluationToRunAgain() async {
        let (sut, tokenStore) = makeSUT(hasValidStoredTokenResults: [true, false])

        await sut.evaluateStoredTokenIfNeeded()
        sut.showLogin()
        await sut.evaluateStoredTokenIfNeeded()

        XCTAssertEqual(tokenStore.loadCallCount, 2)
        XCTAssertEqual(sut.route, .login)
    }

    // MARK: - Helpers

    private func makeSUT(hasValidStoredTokenResults: [Bool] = [],
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (AppCoordinator, TokenStoreStub) {
        let (dependencies, tokenStore) = makeDependencies(hasValidStoredTokenResults: hasValidStoredTokenResults)
        let sut = AppCoordinator(dependencies: dependencies)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(dependencies, file: file, line: line)
        trackForMemoryLeaks(tokenStore, file: file, line: line)
        return (sut, tokenStore)
    }

    private func anyItem(id: String = UUID().uuidString) -> ProductViewModel.Item {
        ProductViewModel.Item(id: id, name: "Any", salesCount: 0)
    }

    private func makeDependencies(hasValidStoredTokenResults: [Bool]) -> (dependencies: Dependencies, tokenStore: TokenStoreStub) {
        let tokenStore = TokenStoreStub(loadResults: makeLoadResults(from: hasValidStoredTokenResults))
        let dependencies = Dependencies(client: HTTPClientStub(),
                                        tokenStore: tokenStore,
                                        authenticationURL: makeTestURL(),
                                        productsURL: makeTestURL(),
                                        salesURL: makeTestURL(),
                                        ratesURL: makeTestURL())
        return (dependencies, tokenStore)
    }

    private func makeLoadResults(from boolResults: [Bool]) -> [Result<AccessToken, Swift.Error>] {
        boolResults.map { isValid in
            let expiration = isValid ? Date().addingTimeInterval(3600) : Date().addingTimeInterval(-3600)
            return .success(AccessToken(value: UUID().uuidString, expirationDate: expiration))
        }
    }

    private func testURL() -> URL {
        URL(string: "https://example.com/\(UUID().uuidString)")!
    }
}

// MARK: - Test doubles

private final class TokenStoreStub: TokenStore {
    private var loadResults: [Result<AccessToken, Swift.Error>]
    private(set) var loadCallCount = 0
    private(set) var clearCallCount = 0

    init(loadResults: [Result<AccessToken, Swift.Error>] = []) {
        self.loadResults = loadResults
    }

    func save(token: AccessToken) async -> Result<Void, Swift.Error> {
        .success(())
    }

    func load() async -> Result<AccessToken, Swift.Error> {
        loadCallCount += 1
        guard !loadResults.isEmpty else {
            return .failure(NSError(domain: "TokenStoreStub", code: -1))
        }
        return loadResults.removeFirst()
    }

    func clear() {
        clearCallCount += 1
    }
}

private final class HTTPClientStub: HTTPClient {
    func perform(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        (Data(), HTTPURLResponse(url: makeTestURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

private func makeTestURL() -> URL {
    URL(string: "https://example.com/\(UUID().uuidString)")!
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

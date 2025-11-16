//
//  AppCoordinator.swift
//  SaleAssistantiOSApp
//
//  Created by Matt on 05/11/2025.
//

import SwiftUI
import Combine
import SaleAssistant

@MainActor
final class AppCoordinator: ObservableObject {
    enum Route {
        case idle
        case login
        case products
    }

    enum Destination: Hashable {
        case product(ProductViewModel.Item)
    }

    @Published private(set) var route: Route = .idle
    @Published var path: [Destination] = []

    private let dependencies: Dependencies
    private lazy var loginViewModel = dependencies.loginViewModel
    private lazy var productViewModel = dependencies.productViewModel
    private var hasEvaluatedStoredToken = false

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func showLogin() {
        route = .login
        path.removeAll()
        hasEvaluatedStoredToken = false
    }

    func showProducts() {
        route = .products
        path.removeAll()
    }

    func showDetail(for item: ProductViewModel.Item) {
        if route != .products {
            showProducts()
        }
        path = [.product(item)]
    }

    func logout() {
        dependencies.resetSession()
        showLogin()
    }

    @ViewBuilder
    func rootView() -> some View {
        switch route {
        case .idle:
            ProgressView()
                .task {
                    await self.evaluateStoredTokenIfNeeded()
            }
        case .login:
            LoginView(viewModel: loginViewModel,
                      onSuccess: { [weak self] in self?.showProducts() })

        case .products:
            productListView()
        }
    }

    @ViewBuilder
    func destination(for destination: Destination) -> some View {
        switch destination {
        case .product(let item):
            detailView(for: item)
        }
    }

    private func productListView() -> some View {
        ProductListView(viewModel: productViewModel,
                        onSelect: { [weak self] item in self?.showDetail(for: item) },
                        onSessionExpired: { [weak self] in self?.logout() })
    }

    private func detailView(for item: ProductViewModel.Item) -> some View {
        ProductDetailView(viewModel: dependencies.makeProductDetailViewModel(for: Product(id: item.id, name: item.name)),
                          onSessionExpired: { [weak self] in self?.logout() })
    }

    func evaluateStoredTokenIfNeeded() async {
        guard !hasEvaluatedStoredToken else { return }
        hasEvaluatedStoredToken = true
        let hasValidToken = await dependencies.hasValidStoredToken()
        if hasValidToken {
            showProducts()
        } else {
            showLogin()
        }
    }
}

struct AppCoordinatorView: View {
    @StateObject private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.rootView()
                .animation(.default, value: coordinator.route)
                .navigationDestination(for: AppCoordinator.Destination.self) { destination in
                    coordinator.destination(for: destination)
                }
        }
    }
}

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
    enum Route: Equatable {
        case login
        case productList
        case product(ProductViewModel.Item)
    }

    @Published private(set) var route: Route = .login
    @Published var path: [ProductViewModel.Item] = []

    private let dependencies: Dependencies
    private lazy var loginViewModel = dependencies.loginViewModel
    private lazy var productViewModel = dependencies.productViewModel

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func showLogin() {
        route = .login
        path.removeAll()
    }

    func showProducts() {
        route = .productList
        path.removeAll()
    }

    func showDetail(for item: ProductViewModel.Item) {
        if route != .productList {
            showProducts()
        }
        if !path.contains(item) {
            path.append(item)
        }
    }

    func logout() {
        dependencies.resetSession()
        showLogin()
    }

    @ViewBuilder
    func viewForCurrentRoute() -> some View {
        switch route {
        case .login:
            LoginView(viewModel: loginViewModel,
                      onSuccess: { [weak self] in self?.showProducts() })
        case .productList:
            ProductListView(viewModel: productViewModel,
                            onLogout: { [weak self] in self?.logout() },
                            onSelect: { [weak self] item in self?.showDetail(for: item) })
        case .product(let item):
            destination(for: item)
        }
    
    }

    func destination(for item: ProductViewModel.Item) -> some View {
        ProductDetailView(viewModel: dependencies.makeProductDetailViewModel(for: Product(id: item.id, name: item.name)))
    }
}

struct AppCoordinatorView: View {
    @StateObject private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.viewForCurrentRoute()
                .animation(.default, value: coordinator.route)
                .navigationDestination(for: ProductViewModel.Item.self) { item in
                    coordinator.destination(for: item)
                }
        }
    }
}

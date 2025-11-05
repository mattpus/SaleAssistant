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
        case login
        case productList
    }

    @Published private(set) var route: Route = .login

    private let dependencies: Dependencies
    private lazy var loginViewModel = dependencies.loginViewModel
    private lazy var productViewModel = dependencies.productViewModel

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func showLogin() {
        route = .login
    }

    func showProducts() {
        route = .productList
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
                            onSelect: { _ in })
        }
    }

}

struct AppCoordinatorView: View {
    @StateObject private var coordinator: AppCoordinator

    init(coordinator: AppCoordinator) {
        _coordinator = StateObject(wrappedValue: coordinator)
    }

    var body: some View {
        coordinator.viewForCurrentRoute()
            .animation(.default, value: coordinator.route)
    }
}

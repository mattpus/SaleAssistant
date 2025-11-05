//
//  SaleAssistantiOSApp.swift
//  SaleAssistantiOSApp
//
//  Created by Matt on 05/11/2025.
//

import SwiftUI

@main
struct SaleAssistantiOSApp: App {

    @StateObject var coordinator = AppCoordinator(dependencies: Dependencies())

    var body: some Scene {
        WindowGroup {
            AppCoordinatorView(coordinator: self.coordinator)
        }
    }
}

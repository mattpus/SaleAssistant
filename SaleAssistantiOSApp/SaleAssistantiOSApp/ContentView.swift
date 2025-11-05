//
//  ContentView.swift
//  SaleAssistantiOSApp
//
//  Created by Matt on 05/11/2025.
//

import SwiftUI
import SaleAssistant

struct ContentView: View {
    @EnvironmentObject private var dependencies: Dependencies

    var body: some View {
        NavigationStack {
            List(dependencies.productViewModel.items) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text("Sales count: \(item.salesCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Products")
            .overlay { emptyState }
            .task {
                await dependencies.productViewModel.load()
            }
            .refreshable {
                await dependencies.productViewModel.load()
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if dependencies.productViewModel.items.isEmpty,
           !dependencies.productViewModel.isLoading {
            ContentUnavailableView("No Products",
                                   systemImage: "shippingbox",
                                   description: Text("Products will appear once available."))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(Dependencies())
}

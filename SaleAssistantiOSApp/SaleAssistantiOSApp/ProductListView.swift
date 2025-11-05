//
//  ProductListView.swift
//  SaleAssistantiOSApp
//
//  Created by Matt on 05/11/2025.
//

import SwiftUI
import SaleAssistant

struct ProductListView: View {
    @ObservedObject var viewModel: ProductViewModel
    let onLogout: () -> Void
    let onSelect: (ProductViewModel.Item) -> Void

    var body: some View {
        NavigationStack {
            List(viewModel.items) { item in
                Button(action: { onSelect(item) }) {
                    HStack(spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                        Spacer()
                        Text("\(item.salesCount) sales")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Products")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Logout", action: onLogout)
                }
            }
            .overlay { overlayContent }
            .task {
                await viewModel.load()
            }
            .refreshable {
                await viewModel.load()
            }
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        if viewModel.isLoading && viewModel.items.isEmpty {
            ProgressView()
        } else if viewModel.items.isEmpty {
            ContentUnavailableView("No Products",
                                   systemImage: "shippingbox",
                                   description: Text("Products will appear once available."))
        }
    }
}

#Preview {
    ProductListView(viewModel: ProductViewModel(productsLoader: PreviewProductsLoader(),
                                               salesLoader: PreviewSalesLoader()),
                    onLogout: {},
                    onSelect: { _ in })
}

private final class PreviewProductsLoader: ProductsLoading {
    func loadProducts() async throws -> [Product] {
        [Product(id: UUID().uuidString, name: "Example Product")]
    }
}

private final class PreviewSalesLoader: SalesLoading {
    func loadSales() async throws -> [Sale] {
        []
    }
}

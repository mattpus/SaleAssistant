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
    let onSelect: (ProductViewModel.Item) -> Void
    let onSessionExpired: () -> Void
    @State private var hasPerformedInitialLoad = false
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                ProgressView("Loading products…")
                    .progressViewStyle(.circular)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView("No Products",
                                       systemImage: "shippingbox",
                                       description: Text("Products will appear once available."))
            } else {
                listContent
            }
        }
        .navigationTitle("Products")
        .task {
            await performInitialLoadIfNeeded()
        }
        .refreshable {
            await viewModel.load()
        }
        .onChange(of: viewModel.sessionExpired) { _, expired in
            if expired {
                onSessionExpired()
            }
        }
    }

    private var listContent: some View {
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func performInitialLoadIfNeeded() async {
        guard !hasPerformedInitialLoad else { return }
        hasPerformedInitialLoad = true
        await viewModel.load()
    }
}


#Preview {
    class PreviewProductsLoader: ProductsLoading {
        func loadProducts() async throws -> [Product] {
            [Product(id: UUID().uuidString, name: "Example Product")]
        }
    }
    
    class PreviewSalesLoader: SalesLoading {
        func loadSales() async throws -> [Sale] {
            []
        }
    }
    
    return ProductListView(viewModel: ProductViewModel(productsLoader: PreviewProductsLoader(),
                                                       salesLoader: PreviewSalesLoader()),
                           onSelect: { _ in },
                           onSessionExpired: {})
}

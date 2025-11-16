//
//  ProductDetailView.swift
//  SaleAssistantiOSApp
//
//  Created by OpenAI Assistant on 05/11/2025.
//

import SwiftUI
import SaleAssistant

struct ProductDetailView: View {
    @ObservedObject var viewModel: ProductDetailViewModel
    let onSessionExpired: () -> Void
    @State private var showPatienceMessage = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 8) {
                    ProgressView("Loading product details...")
                        .progressViewStyle(.circular)
                    if showPatienceMessage {
                        Text("Please be patient, calculating rates...")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .task(id: viewModel.isLoading) {
                    // Reset when loading state changes
                    showPatienceMessage = false
                    if viewModel.isLoading {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if !Task.isCancelled && viewModel.isLoading {
                            withAnimation { showPatienceMessage = true }
                        }
                    }
                }
            } else {
                detailContent
            }
        }
        .navigationTitle(viewModel.productName)
        .task {
            await viewModel.load()
        }
        .onChange(of: viewModel.isLoading) { _, isLoading in
            if !isLoading {
                showPatienceMessage = false
            }
        }
        .onChange(of: viewModel.sessionExpired) { _, expired in
            if expired {
                onSessionExpired()
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        List {
            if let message = viewModel.error?.localizedDescription {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section(header: Text("Summary")) {
                LabeledContent("Total sales", value: "\(viewModel.salesCount)")
                LabeledContent("Total (USD)", value: viewModel.totalSalesUSD.formatted(.currency(code: "USD")))
            }

            Section(header: Text("Sales")) {
                ForEach(viewModel.saleItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(item.originalAmount.formatted()) \(item.originalCurrency)")
                            Spacer()
                            Text(item.usdAmount.formatted(.currency(code: "USD")))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

#Preview {
    class PreviewSalesLoader: SalesLoading {
       func loadSales() async throws -> [Sale] {
           []
       }
   }

    class PreviewRatesLoader: RatesLoading {
       func loadRates() async throws -> [String : Decimal] {
           [:]
       }
   }

    return ProductDetailView(viewModel: ProductDetailViewModel(product: Product(id: UUID().uuidString, name: "Preview Product"),
                                                       salesLoader: PreviewSalesLoader(),
                                                       ratesLoader: PreviewRatesLoader()),
                             onSessionExpired: {})
}

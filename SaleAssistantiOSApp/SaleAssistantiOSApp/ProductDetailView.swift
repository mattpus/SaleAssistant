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

    var body: some View {
        List {
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
        .navigationTitle(viewModel.productName)
        .task {
            await viewModel.load()
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

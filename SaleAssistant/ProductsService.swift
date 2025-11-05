//
//  ProductsService.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

public final class ProductsService {
    
    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
    }

    private let url: URL
    private let client: HTTPClient
    private let decoder: JSONDecoder

    public init(url: URL,
                client: HTTPClient,
                decoder: JSONDecoder = JSONDecoder()) {
        self.url = url
        self.client = client
        self.decoder = decoder
    }

    public func loadProducts() async throws -> [Product] {
        let payload: (data: Data, response: HTTPURLResponse)

        do {
            payload = try await client.perform(request: URLRequest(url: url))
        } catch {
            throw Error.connectivity
        }

        guard payload.response.statusCode == 200 else {
            throw Error.invalidData
        }

        do {
            return try decoder.decode([ProductDTO].self, from: payload.data).map(\.model)
        } catch {
            throw Error.invalidData
        }
    }
}

public struct Product {
    let name: String
    let sales: Int
}

private struct ProductDTO: Decodable {
    struct Name: Decodable {
        let common: String
    }

    let name: Name
    let sales: Int

    var model: Product {
        Product(
            name: name.common,
            sales: sales
        )
    }
}

//
//  ProductsService.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

public final class ProductsService: ProductsLoading {
    
    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
        case unauthorized
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
            if payload.response.statusCode == 401 {
                throw Error.unauthorized
            }
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
    let id: String
    let name: String
}

private struct ProductDTO: Decodable {
    let id: String
    let name: String

    var model: Product {
        Product(
            id: id,
            name: name
        )
    }
}

//
//  RatesService.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Foundation

public final class RatesService: RatesLoading {

    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
        case unauthorized
        
        var message : String {
            switch self {
            case .connectivity:
                return "Failed to connect to /rates service. Please check your internet connection and try again."
            case .invalidData:
                return "We couldn't process the server response for rate service. Please try again later."
            case .unauthorized:
                return "Your session has expired or you don't have access. Please sign in again to continue."
            }
        }
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

    public func loadRates() async throws -> [String: Decimal] {
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
            return try makeRates(from: payload.data)
        } catch {
            throw Error.invalidData
        }
    }

    private func makeRates(from data: Data) throws -> [String: Decimal] {
        let rateDTOs = try decoder.decode([RateDTO].self, from: data)
        var result: [String: Decimal] = [:]

        for dto in rateDTOs {
            guard dto.to.uppercased() == "USD" else { continue }
            result[dto.from.uppercased()] = dto.rate
        }

        if result.isEmpty {
            throw Error.invalidData
        }

        return result
    }
}

private struct RateDTO: Decodable {
    let from: String
    let to: String
    let rate: Decimal
}

//
//  SalesService.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

import Foundation

public final class SalesService: SalesLoading {

    public enum Error: Swift.Error, Equatable {
        case connectivity
        case invalidData
        case unauthorized
        
        var message : String {
            switch self {
            case .connectivity:
                return "You're offline. Please check your internet connection and try again."
            case .invalidData:
                return "We couldn't process the server response. Please try again later or contact support if the issue persists."
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

    public func loadSales() async throws -> [Sale] {
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
            return try decoder.decode([SaleDTO].self, from: payload.data).map(\.model)
        } catch {
            throw Error.invalidData
        }
    }
}

public struct Sale: Identifiable, Sendable {
    public let id: UUID
    public let productID: String
    public let currencyCode: String
    public let amount: Decimal
    public let date: Date

    public init(id: UUID = UUID(), productID: String, currencyCode: String, amount: Decimal, date: Date) {
        self.id = id
        self.productID = productID
        self.currencyCode = currencyCode
        self.amount = amount
        self.date = date
    }
}

private struct SaleDTO: Decodable, Sendable {
    
    let productID: String
    let currencyCode: String
    let amount: Decimal
    let date: Date

    enum CodingKeys: String, CodingKey {
        case productID = "product_id"
        case currencyCode = "currency_code"
        case amount
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        productID = try container.decode(String.self, forKey: .productID)
        currencyCode = try container.decode(String.self, forKey: .currencyCode)
        let dateString = try container.decode(String.self, forKey: .date)
        guard let parsedDate = Formatters.iso8601Formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .date,
                                                   in: container,
                                                   debugDescription: "Invalid date format")
        }
        date = parsedDate
        let amountString = try container.decode(String.self, forKey: .amount)
        let decimalNumber = NSDecimalNumber(string: amountString, locale: Locale(identifier: "en_US_POSIX"))
        guard decimalNumber != .notANumber else {
            throw DecodingError.dataCorruptedError(forKey: .amount,
                                                   in: container,
                                                   debugDescription: "Invalid decimal amount")
        }
        amount = decimalNumber.decimalValue
    }

    var model: Sale {
        Sale(productID: productID,
             currencyCode: currencyCode,
             amount: amount,
             date: date)
    }
}

enum Formatters {
    static var iso8601Formatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}


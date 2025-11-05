//
//  AccessToken.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation 

public struct AccessToken: Decodable, Equatable {
    public let value: String
    public let expirationDate: Date

    public init(value: String, expirationDate: Date) {
        self.value = value
        self.expirationDate = expirationDate
    }

    public var isValid: Bool {
        expirationDate > Date()
    }
}

//
//  AccessToken.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation 

public struct AccessToken {
    let value: String
    let expirationDate: Date
    var isValid: Bool {
        expirationDate > Date()
    }
}

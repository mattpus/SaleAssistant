//
//  UserFacingError.swift
//  SaleAssistantiOSApp
//
//  Created by Matt on 15/11/2025.
//

import Foundation

struct UserFacingError: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

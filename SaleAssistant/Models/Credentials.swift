//
//  Credentials.swift
//  SaleAssistant
//
//  Created by Matt on 05/11/2025.
//

public struct Credentials: Decodable, Sendable {
    public let login: String
    public let password: String

    public init(login: String, password: String) {
        self.login = login
        self.password = password
    }
}

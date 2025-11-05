//
//  HTTPClient.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import Foundation

public protocol HTTPClient {
    func perform(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse)
}

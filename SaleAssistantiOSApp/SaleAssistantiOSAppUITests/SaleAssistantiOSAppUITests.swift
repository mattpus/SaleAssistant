//
//  SaleAssistantiOSAppUITests.swift
//  SaleAssistantiOSAppUITests
//
//  Created by Matt on 05/11/2025.
//

import XCTest

final class SaleAssistantiOSAppUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        
    }
}

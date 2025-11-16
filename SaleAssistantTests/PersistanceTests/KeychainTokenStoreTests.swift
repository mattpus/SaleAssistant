//
//  KeychainTokenStoreTests.swift
//  SaleAssistant
//
//  Created by Matt on 03/11/2025.
//

import XCTest
@testable import SaleAssistant

@MainActor
class KeychainTokenStoreTests: XCTestCase {
    func test_load_returnsErrorWhenNothingSaved() async {
        let sut = makeSut()
        
        let result = await sut.load()
        
        switch result {
        case let .failure(error):
            guard case .dataNotFound? = error as? KeychainTokenStore.Error else {
                return XCTFail("Expected dataNotFound error, got \(error)")
            }
        case .success:
            XCTFail("Expected failure, got success")
        }
    }
    
    func test_load_returnsLastSavedToken() async {
        let sut = makeSut()
        let token1 = makeToken(value: "token-1", expirationDate: Date(timeIntervalSince1970: 1))
        let token2 = makeToken(value: "token-2", expirationDate: Date(timeIntervalSince1970: 2))
        
        XCTAssertResultSuccess(await sut.save(token: token1))
        XCTAssertResultSuccess(await sut.save(token: token2))
        
        let result = await sut.load()
        
        switch result {
        case let .success(loadedToken):
            XCTAssertEqual(loadedToken.value, token2.value)
            XCTAssertEqual(loadedToken.expirationDate, token2.expirationDate)
        case let .failure(error):
            XCTFail("Expected success, got error \(error)")
        }
    }
   
    func test_clear_removesSavedToken() async {
        let sut = makeSut()
        let token = makeToken(value: "token", expirationDate: Date(timeIntervalSince1970: 3))
        
        XCTAssertResultSuccess(await sut.save(token: token))
        
        sut.clear()
        
        let result = await sut.load()
        
        switch result {
        case let .failure(error):
            guard case .dataNotFound? = error as? KeychainTokenStore.Error else {
                return XCTFail("Expected dataNotFound error, got \(error)")
            }
        case .success:
            XCTFail("Expected failure, got success")
        }
    }
    
    // MARK: Helpers
    
    private func makeSut(file: StaticString = #file, line: UInt = #line) -> KeychainTokenStore {
        let key = "KeychainTokenStore.tests.tokenKey"
        let sut = KeychainTokenStore(key: key)
       
        addTeardownBlock {
            KeychainTokenStore(key: key).clear()
        }
        trackForMemoryLeaks(sut, file: file, line: line)
        return sut
    }
    
    private func makeToken(value: String = UUID().uuidString,  expirationDate: Date = Date()) -> AccessToken {
        AccessToken(value: value, expirationDate: expirationDate)
    }
    
    private func XCTAssertResultSuccess(_ result: Result<Void, Swift.Error>, file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case .success:
            break
        case let .failure(error):
            XCTFail("Expected success, got \(error)", file: file, line: line)
        }
    }
}

//
//  AuthenticationServiceTests.swift
//  SaleAssistantTests
//
//  Created by Matt on 05/11/2025.
//

import XCTest
@testable import SaleAssistant

@MainActor
final class AuthenticationServiceTests: XCTestCase {
    func test_authenticate_requestsDataFromURL() async throws {
        let url = anyURL()
        let (sut, client, _) = makeSUT(url: url)
        client.stubAuthenticatedResult(with: makeAccessTokenData())

        _ = try await sut.authenticate(with: Credentials(login: "user", password: "pass"))

        XCTAssertEqual(client.requestedURLs, [url])
    }

    func test_authenticate_usesPOSTMethod() async throws {
        let credentials = Credentials(login: "user", password: "pass")
        let (sut, client, _) = makeSUT()
        client.stubAuthenticatedResult(with: makeAccessTokenData())
        
        _ = try await sut.authenticate(with: credentials)
        
        XCTAssertEqual(client.requests.first?.httpMethod, "POST")
    }
    
    func test_authenticate_setsJSONBodyWithCredentials() async throws {
        let credentials = Credentials(login: "user", password: "pass")
        let (sut, client, _) = makeSUT()
        client.stubAuthenticatedResult(with: makeAccessTokenData())
        
        _ = try await sut.authenticate(with: credentials)
        
        let request = try XCTUnwrap(client.requests.first)
        let bodyData = try XCTUnwrap(request.httpBody)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: String])
        XCTAssertEqual(jsonObject["username"], credentials.login)
        XCTAssertEqual(jsonObject["password"], credentials.password)
    }
    
    func test_authenticate_setsContentTypeHeaderToJSON() async throws {
        let credentials = Credentials(login: "user", password: "pass")
        let (sut, client, _) = makeSUT()
        client.stubAuthenticatedResult(with: makeAccessTokenData())
        
        _ = try await sut.authenticate(with: credentials)
        
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_authenticate_deliversAccessTokenOn200ResponseWithValidJSON() async throws {
        let token = AccessToken(value: "token", expirationDate: Date().addingTimeInterval(120))
        let (sut, client, _) = makeSUT()
        client.stubAuthenticatedResult(with: makeAccessTokenData(for: token))

        let receivedToken = try await sut.authenticate(with: Credentials(login: "user", password: "pass"))

        XCTAssertEqual(receivedToken.value, token.value)
        XCTAssertEqual(receivedToken.expirationDate.description, token.expirationDate.description)
    }

    func test_authenticate_throwsConnectivityErrorOnClientFailure() async {
        let (sut, client, _) = makeSUT()
        client.stub(result: .failure(anyNSError()))

        do {
            _ = try await sut.authenticate(with: Credentials(login: "user", password: "pass"))
            XCTFail("Expected to throw, got success instead")
        } catch let error as AuthenticationService.Error {
            XCTAssertEqual(error, .connectivity)
        } catch {
            XCTFail("Expected AuthenticationService.Error.connectivity, got \(error)")
        }
    }

    func test_authenticate_throwsInvalidDataOnNon200Response() async {
        let (sut, client, _) = makeSUT()
        client.stub(result: .success((Data(), anyHTTPResponse(statusCode: 400))))

        do {
            _ = try await sut.authenticate(with: Credentials(login: "user", password: "pass"))
            XCTFail("Expected to throw, got success instead")
        } catch let error as AuthenticationService.Error {
            XCTAssertEqual(error, .invalidData)
        } catch {
            XCTFail("Expected AuthenticationService.Error.connectivity, got \(error)")
        }
    }

    func test_authenticate_throwsInvalidDataOnInvalidJSON() async {
        let (sut, client, _) = makeSUT()
        client.stub(result: .success((Data("invalid json".utf8), anyHTTPResponse())))

        do {
            _ = try await sut.authenticate(with: Credentials(login: "user", password: "pass"))
            XCTFail("Expected to throw, got success instead")
        } catch let error as AuthenticationService.Error {
            XCTAssertEqual(error, .invalidData)
        } catch {
            XCTFail("Expected AuthenticationService.Error.invalidData, got \(error)")
        }
    }

    func test_authenticate_savesTokenUsingTokenSaver() async throws {
        let token = AccessToken(value: "token", expirationDate: Date().addingTimeInterval(180))
        let (sut, client, tokenSaver) = makeSUT()
        client.stubAuthenticatedResult(with: makeAccessTokenData(for: token))

        _ = try await sut.authenticate(with: Credentials(login: "user", password: "pass"))

        XCTAssertEqual(tokenSaver.savedTokens.first?.value, token.value)
    }

    func test_authenticate_throwsSaverErrorWhenSaveFails() async {
        let expectedError = anyNSError()
        let token = AccessToken(value: "token", expirationDate: Date().addingTimeInterval(180))
        let (sut, client, tokenSaver) = makeSUT()
        client.stubAuthenticatedResult(with: makeAccessTokenData(for: token))
        tokenSaver.saveResult = .failure(expectedError)

        do {
            _ = try await sut.authenticate(with: Credentials(login: "user", password: "pass"))
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual((error as NSError).code, expectedError.code)
        }
    }

    // MARK: - Helpers

    private func makeSUT(url: URL = anyURL(),
                         file: StaticString = #filePath,
                         line: UInt = #line) -> (AuthenticationService, HTTPClientSpy, TokenSaverSpy) {
        let client = HTTPClientSpy()
        let tokenSaver = TokenSaverSpy()
        let sut = AuthenticationService(url: url, client: client, tokenSaver: tokenSaver)
        trackForMemoryLeaks(client, file: file, line: line)
        trackForMemoryLeaks(tokenSaver, file: file, line: line)
        trackForMemoryLeaks(sut, file: file, line: line)
        return (sut, client, tokenSaver)
    }

    private func makeAccessTokenData(for token: AccessToken? = nil) -> Data {
        let token = token ?? AccessToken(value: "token", expirationDate: Date().addingTimeInterval(180))
        return try! JSONSerialization.data(withJSONObject: ["access_token": token.value])
    }
}

private extension HTTPClientSpy {
    func stubAuthenticatedResult(with data: Data, statusCode: Int = 200) {
        stub(result: .success((data, anyHTTPResponse(statusCode: statusCode))))
    }
}

private final class TokenSaverSpy: TokenSaver {
    private(set) var savedTokens: [AccessToken] = []
    var saveResult: Result<Void, Swift.Error> = .success(())

    func save(token: AccessToken) async -> Result<Void, Swift.Error> {
        savedTokens.append(token)
        return saveResult
    }
}

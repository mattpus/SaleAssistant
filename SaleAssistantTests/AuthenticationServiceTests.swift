//
//  AuthenticationServiceTests.swift
//  SaleAssistantTests
//
//  Created by OpenAI Assistant on 05/11/2025.
//

import XCTest
@testable import SaleAssistant

@MainActor
final class AuthenticationServiceTests: XCTestCase {
    func test_authorize_requestsDataFromURL() async throws {
        let url = anyURL()
        let (sut, client, _) = makeSUT(url: url)
        client.stubAuthorizedResult(with: makeAccessTokenData())

        _ = try await sut.authorize(with: Credentials(login: "user", password: "pass"))

        XCTAssertEqual(client.requestedURLs, [url])
    }

    func test_authorize_usesPOSTMethod() async throws {
        let credentials = Credentials(login: "user", password: "pass")
        let (sut, client, _) = makeSUT()
        client.stubAuthorizedResult(with: makeAccessTokenData())
        
        _ = try await sut.authorize(with: credentials)
        
        XCTAssertEqual(client.requests.first?.httpMethod, "POST")
    }
    
    func test_authorize_setsJSONBodyWithCredentials() async throws {
        let credentials = Credentials(login: "user", password: "pass")
        let (sut, client, _) = makeSUT()
        client.stubAuthorizedResult(with: makeAccessTokenData())
        
        _ = try await sut.authorize(with: credentials)
        
        let request = try XCTUnwrap(client.requests.first)
        let bodyData = try XCTUnwrap(request.httpBody)
        let jsonObject = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: String])
        XCTAssertEqual(jsonObject["username"], credentials.login)
        XCTAssertEqual(jsonObject["password"], credentials.password)
    }
    
    func test_authorize_setsContentTypeHeaderToJSON() async throws {
        let credentials = Credentials(login: "user", password: "pass")
        let (sut, client, _) = makeSUT()
        client.stubAuthorizedResult(with: makeAccessTokenData())
        
        _ = try await sut.authorize(with: credentials)
        
        XCTAssertEqual(client.requests.first?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func test_authorize_deliversAccessTokenOn200ResponseWithValidJSON() async throws {
        let token = AccessToken(value: "token", expirationDate: Date().addingTimeInterval(3600))
        let (sut, client, _) = makeSUT()
        client.stubAuthorizedResult(with: makeAccessTokenData(for: token))

        let receivedToken = try await sut.authorize(with: Credentials(login: "user", password: "pass"))

        XCTAssertEqual(receivedToken.value, token.value)
        XCTAssertEqual(receivedToken.expirationDate, token.expirationDate)
    }

    func test_authorize_throwsConnectivityErrorOnClientFailure() async {
        let (sut, client, _) = makeSUT()
        client.stub(result: .failure(anyNSError()))

        do {
            _ = try await sut.authorize(with: Credentials(login: "user", password: "pass"))
            XCTFail("Expected to throw, got success instead")
        } catch let error as AuthenticationService.Error {
            XCTAssertEqual(error, .connectivity)
        } catch {
            XCTFail("Expected AuthenticationService.Error.connectivity, got \(error)")
        }
    }

    func test_authorize_throwsInvalidDataOnNon200Response() async {
        let (sut, client, _) = makeSUT()
        client.stub(result: .success((Data(), anyHTTPResponse(statusCode: 400))))

        do {
            _ = try await sut.authorize(with: Credentials(login: "user", password: "pass"))
            XCTFail("Expected to throw, got success instead")
        } catch let error as AuthenticationService.Error {
            XCTAssertEqual(error, .connectivity)
        } catch {
            XCTFail("Expected AuthenticationService.Error.connectivity, got \(error)")
        }
    }

    func test_authorize_throwsInvalidDataOnInvalidJSON() async {
        let (sut, client, _) = makeSUT()
        client.stub(result: .success((Data("invalid json".utf8), anyHTTPResponse())))

        do {
            _ = try await sut.authorize(with: Credentials(login: "user", password: "pass"))
            XCTFail("Expected to throw, got success instead")
        } catch let error as AuthenticationService.Error {
            XCTAssertEqual(error, .invalidData)
        } catch {
            XCTFail("Expected AuthenticationService.Error.invalidData, got \(error)")
        }
    }

    func test_refreshToken_returnsValueFromAuthorize() async throws {
        let expectedToken = "refreshed-token"
        let accessToken = AccessToken(value: expectedToken, expirationDate: Date().addingTimeInterval(3600))
        let (sut, client, _) = makeSUT()
        client.stubAuthorizedResult(with: makeAccessTokenData(for: accessToken))

        let token = try await sut.refreshToken()

        XCTAssertEqual(token, expectedToken)
    }

    func test_authorize_savesTokenUsingTokenSaver() async throws {
        let token = AccessToken(value: "token", expirationDate: Date().addingTimeInterval(3600))
        let (sut, client, tokenSaver) = makeSUT()
        client.stubAuthorizedResult(with: makeAccessTokenData(for: token))

        _ = try await sut.authorize(with: Credentials(login: "user", password: "pass"))

        XCTAssertEqual(tokenSaver.savedTokens, [token])
    }

    func test_authorize_throwsSaverErrorWhenSaveFails() async {
        let expectedError = anyNSError()
        let token = AccessToken(value: "token", expirationDate: Date().addingTimeInterval(3600))
        let (sut, client, tokenSaver) = makeSUT()
        client.stubAuthorizedResult(with: makeAccessTokenData(for: token))
        tokenSaver.saveResult = .failure(expectedError)

        do {
            _ = try await sut.authorize(with: Credentials(login: "user", password: "pass"))
            XCTFail("Expected to throw, got success instead")
        } catch {
            XCTAssertEqual(error as NSError, expectedError)
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
        let token = token ?? AccessToken(value: "token", expirationDate: Date().addingTimeInterval(3600))
        let codable = CodableToken(token: token)
        return try! JSONEncoder().encode(codable)
    }

    private struct CodableToken: Encodable {
        let value: String
        let expirationDate: Date

        init(token: AccessToken) {
            self.value = token.value
            self.expirationDate = token.expirationDate
        }
    }
}

private extension HTTPClientSpy {
    func stubAuthorizedResult(with data: Data, statusCode: Int = 200) {
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

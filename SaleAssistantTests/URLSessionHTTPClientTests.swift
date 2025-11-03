import XCTest
@testable import SaleAssistant

@MainActor
final class URLSessionHTTPClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.startInterceptingRequests()
    }

    override func tearDown() {
        super.tearDown()
        URLProtocolStub.stopInterceptingRequests()
    }

    func test_getFromURL_performsGETRequestWithURL() async throws {
        let url = anyURL()
        let expectation = expectation(description: "Wait for request")

        URLProtocolStub.stub(data: nil, response: nil, error: anyNSError())
        URLProtocolStub.observeRequests { request in
            XCTAssertEqual(request.url, url)
            XCTAssertEqual(request.httpMethod, "GET")
            expectation.fulfill()
        }

        let sut = makeSUT()

        _ = try? await sut.get(from: url)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func test_getFromURL_failsOnRequestError() async {
        let url = anyURL()
        let expectedError = anyNSError()
        URLProtocolStub.stub(data: nil, response: nil, error: expectedError)

        let sut = makeSUT()

        do {
            _ = try await sut.get(from: url)
            XCTFail("Expected error")
        } catch {
            let receivedError = error as NSError
            XCTAssertEqual(receivedError.domain, expectedError.domain)
            XCTAssertEqual(receivedError.code, expectedError.code)
        }
    }

    func test_getFromURL_deliversDataAndHTTPResponse() async throws {
        let url = anyURL()
        let data = Data("any data".utf8)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        URLProtocolStub.stub(data: data, response: response, error: nil)

        let sut = makeSUT()

        let received = try await sut.get(from: url)

        XCTAssertEqual(received.data, data)
        XCTAssertEqual(received.response.url, response.url)
        XCTAssertEqual(received.response.statusCode, response.statusCode)
        XCTAssertEqual(received.response.mimeType, response.mimeType)
    }

    func test_getFromURL_failsOnNonHTTPURLResponse() async {
        let url = anyURL()
        let data = Data("data".utf8)
        let nonHTTPResponse = URLResponse(url: url, mimeType: nil, expectedContentLength: data.count, textEncodingName: nil)
        URLProtocolStub.stub(data: data, response: nonHTTPResponse, error: nil)

        let sut = makeSUT()

        do {
            _ = try await sut.get(from: url)
            XCTFail("Expected error")
        } catch {
            guard case URLSessionHTTPClient.Error.invalidResponse = error else {
                return XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }

    // MARK: - Helpers

    private func makeSUT(file: StaticString = #file, line: UInt = #line) -> URLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let sut = URLSessionHTTPClient(session: session)
        trackForMemoryLeaks(sut, file: file, line: line)
        trackForMemoryLeaks(session, file: file, line: line)
        return sut
    }
}

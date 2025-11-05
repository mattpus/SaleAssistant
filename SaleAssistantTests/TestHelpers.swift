import Foundation
import XCTest
@testable import SaleAssistant
import Synchronization

extension XCTestCase {
    @MainActor
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #file, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak.", file: file, line: line)
        }
    }
}

func anyURL() -> URL {
    URL(string: "https://example.com")!
}

func anyNSError() -> NSError {
    NSError(domain: "any error", code: 0)
}

func anyData() -> Data {
    Data("any data".utf8)
}

func anyHTTPResponse(statusCode: Int = 200) -> HTTPURLResponse {
    HTTPURLResponse(url: anyURL(), statusCode: statusCode, httpVersion: nil, headerFields: nil)!
}

final class HTTPClientSpy: HTTPClient {
    private(set) var requestedURLs: [URL] = []
    private(set) var requests: [URLRequest] = []
    private var results: [URL: Result<(Data, HTTPURLResponse), Error>] = [:]
    private var defaultResult: Result<(Data, HTTPURLResponse), Error>?

    func stub(result: Result<(Data, HTTPURLResponse), Error>) {
        defaultResult = result
    }

    func stub(result: Result<(Data, HTTPURLResponse), Error>, for url: URL) {
        results[url] = result
    }

    func perform(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        let url = request.url!
        requestedURLs.append(url)
        requests.append(request)

        let result = results[url] ?? defaultResult

        guard let result else {
            fatalError("No stub for URL \(url)")
        }

        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}

final class URLProtocolStub: URLProtocol {
    private struct CustomStub {
        let data: Data?
        let response: URLResponse?
        let error: Error?
    }

    private static let stub = Mutex<CustomStub?>(nil)
    nonisolated(unsafe) private static var requestObserver: ((URLRequest) -> Void)?

    static func startInterceptingRequests() {
        URLProtocol.registerClass(URLProtocolStub.self)
    }

    static func stopInterceptingRequests() {
        URLProtocol.unregisterClass(URLProtocolStub.self)
        stub.withLock({ stub in
            stub = nil
        })
        requestObserver = nil
    }

    static func observeRequests(_ observer: @escaping (URLRequest) -> Void) {
        requestObserver = observer
    }

    static func stub(data: Data?, response: URLResponse?, error: Error?) {
        stub.withLock({ stub in
            stub = CustomStub(data: data, response: response, error: error)
        })
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let requestObserver = URLProtocolStub.requestObserver {
            requestObserver(request)
        }

        // Capture a snapshot of the current stub in a thread-safe manner
        let currentStub: CustomStub? = URLProtocolStub.stub.withLock { stub in
            return stub
        }

        if let data = currentStub?.data {
            client?.urlProtocol(self, didLoad: data)
        }

        if let response = currentStub?.response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        if let error = currentStub?.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

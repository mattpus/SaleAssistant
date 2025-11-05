import Foundation

/// Concrete HTTP client backed by `URLSession`.
public final class URLSessionHTTPClient: HTTPClient {
    /// Errors describing why the request could not complete.
    public enum Error: Swift.Error {
        /// The response was not an `HTTPURLResponse`.
        case invalidResponse
    }

    private let session: URLSession

    /// Creates a client that uses the specified session for requests.
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Sends the provided request and returns the response payload and HTTP metadata.
    public func perform(request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Error.invalidResponse
        }

        return (data, httpResponse)
    }
}

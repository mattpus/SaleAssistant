import Foundation

public protocol HTTPClient {
    func get(from url: URL) async throws -> (data: Data, response: HTTPURLResponse)
}

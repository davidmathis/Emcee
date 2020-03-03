import Models
import Foundation

public protocol NetworkRequest {
    associatedtype Payload: Encodable
    associatedtype Response: Decodable

    var httpMethod: HTTPMethod { get }
    var pathWithLeadingSlash: String { get }
    var payload: Payload? { get }
    var timeout: TimeInterval { get }
}

public extension NetworkRequest {
    var timeout: TimeInterval { return 60 } // default timeout taken from URLRequest
}

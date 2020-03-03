import DistWorkerModels
import Foundation
import RequestSender

public class CurrentlyProcessingBucketsNetworkRequest: NetworkRequest {
    public typealias Payload = CurrentlyProcessingBucketsRequest
    public typealias Response = CurrentlyProcessingBucketsResponse
    
    public let httpMethod: HTTPMethod = .get
    public let pathWithLeadingSlash: String = CurrentlyProcessingBuckets.path.withPrependedSlash
    public let payload: CurrentlyProcessingBucketsRequest? = CurrentlyProcessingBucketsRequest()
    public let timeout: TimeInterval

    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }
}

import CurrentlyBeingProcessedBucketsTracker
import DistWorkerModels
import Foundation
import RESTServer

public final class CurrentlyProcessingBucketsEndpoint: RESTEndpoint {
    public typealias DecodedObjectType = CurrentlyProcessingBucketsRequest
    public typealias ResponseType = CurrentlyProcessingBucketsResponse
    
    private let currentlyBeingProcessedBucketsTracker: CurrentlyBeingProcessedBucketsTracker

    public init(currentlyBeingProcessedBucketsTracker: CurrentlyBeingProcessedBucketsTracker) {
        self.currentlyBeingProcessedBucketsTracker = currentlyBeingProcessedBucketsTracker
    }
    
    public func handle(
        decodedPayload: CurrentlyProcessingBucketsRequest
    ) throws -> CurrentlyProcessingBucketsResponse {
        return CurrentlyProcessingBucketsResponse(
            bucketIds: Array(currentlyBeingProcessedBucketsTracker.bucketIdsBeingProcessed)
        )
    }
}

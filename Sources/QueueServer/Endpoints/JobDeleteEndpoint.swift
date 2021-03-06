import BalancingBucketQueue
import Foundation
import Models
import RESTMethods
import RESTServer

public final class JobDeleteEndpoint: RESTEndpoint {
    private let jobManipulator: JobManipulator
    
    public init(jobManipulator: JobManipulator) {
        self.jobManipulator = jobManipulator
    }
    
    public func handle(decodedPayload: JobDeleteRequest) throws -> JobDeleteResponse {
        try jobManipulator.delete(jobId: decodedPayload.jobId)
        return JobDeleteResponse(jobId: decodedPayload.jobId)
    }
}

import Foundation

public enum RESTMethod: String {
    case bucketResult
    case getBucket
    case queueVersion
    case registerWorker
    case scheduleTests
    case jobState
    case jobResults
    case jobDelete
    
    public var withPrependingSlash: String {
        return "/\(self.rawValue)"
    }
}

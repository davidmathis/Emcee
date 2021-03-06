import Foundation

public final class RunningQueueState: Equatable, CustomStringConvertible, Codable {
    public let enqueuedBucketCount: Int
    public let dequeuedBucketCount: Int
    
    public init(enqueuedBucketCount: Int, dequeuedBucketCount: Int) {
        self.enqueuedBucketCount = enqueuedBucketCount
        self.dequeuedBucketCount = dequeuedBucketCount
    }
    
    public var isDepleted: Bool {
        return enqueuedBucketCount == 0 && dequeuedBucketCount == 0
    }
    
    public static func ==(left: RunningQueueState, right: RunningQueueState) -> Bool {
        return left.enqueuedBucketCount == right.enqueuedBucketCount &&
            left.dequeuedBucketCount == right.dequeuedBucketCount
    }
    
    public var description: String {
        return "<\(type(of: self)): enqueued: \(enqueuedBucketCount), dequeued: \(dequeuedBucketCount)>"
    }
}

import Foundation
import Metrics

public final class QueueStateDequeuedBucketsMetric: Metric {
    public init(
        queueHost: String,
        numberOfDequeuedBuckets: Int
        )
    {
        super.init(
            fixedComponents: [
                "queue",
                "state",
                "dequeued"
            ],
            variableComponents: [
                queueHost,
                Metric.reservedField,
                Metric.reservedField,
                Metric.reservedField,
                Metric.reservedField
            ],
            value: Double(numberOfDequeuedBuckets),
            timestamp: Date()
        )
    }
}

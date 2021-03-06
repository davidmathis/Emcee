import QueueServer
import ScheduleStrategy
import Models
import QueueModels

public class QueueServerFixture: QueueServer {

    public var isDepleted = false
    public var hasAnyAliveWorker = true
    public var ongoingJobIds = Set<JobId>()
    
    public init() {}
    
    public func start() throws -> Int {
        return 1
    }
    
    public func schedule(bucketSplitter: BucketSplitter, testEntryConfigurations: [TestEntryConfiguration], prioritizedJob: PrioritizedJob) {
        ongoingJobIds.insert(prioritizedJob.jobId)
    }
    
    public func queueResults(jobId: JobId) throws -> JobResults {
        return JobResults(jobId: jobId, testingResults: [])
    }
    
}

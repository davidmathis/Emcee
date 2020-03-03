import Foundation
import Models
import QueueServer

public final class FakeWorkerDetailsHolder: WorkerDetailsHolder {
    public init() {}
    
    public func didRegister(workerId: WorkerId, restPort: Int) {
        knownPorts[workerId] = restPort
    }
    
    public var knownPorts: [WorkerId : Int] = [:]
}

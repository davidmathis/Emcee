import AtomicModels
import Foundation
import Models

public final class WorkerDetailsHolderImpl: WorkerDetailsHolder {
    private let storage = AtomicValue<[WorkerId: Int]>([:])
    
    public func didRegister(workerId: WorkerId, restPort: Int) {
        storage.withExclusiveAccess {
            $0[workerId] = restPort
        }
    }
    
    public var knownPorts: [WorkerId: Int] {
        return storage.currentValue()
    }
}

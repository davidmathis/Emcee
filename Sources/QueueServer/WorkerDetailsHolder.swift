import Foundation
import Models

public protocol WorkerDetailsHolder {
    func didRegister(workerId: WorkerId, restPort: Int)
    
    var knownPorts: [WorkerId: Int] { get }
}

import Dispatch
import Foundation
import Logging
import Models
import TemporaryStuff
import ResourceLocationResolver

public final class LazyCachedOnDemandSimulatorPool: OnDemandSimulatorPool {
    private let tempFolder: TemporaryFolder
    private var pools = [SimulatorPoolKey: SimulatorPool]()
    private let syncQueue = DispatchQueue(label: "ru.avito.OnDemandSimulatorPool")
    private let resourceLocationResolver: ResourceLocationResolver
    private let simulatorControllerProvider: (Simulator) throws -> (SimulatorController)
    
    public init(
        resourceLocationResolver: ResourceLocationResolver,
        tempFolder: TemporaryFolder,
        simulatorControllerProvider: @escaping (Simulator) throws -> (SimulatorController)
    ) {
        self.resourceLocationResolver = resourceLocationResolver
        self.tempFolder = tempFolder
        self.simulatorControllerProvider = simulatorControllerProvider
    }
    
    deinit {
        deleteSimulators()
    }
    
    public func pool(key: SimulatorPoolKey) throws -> SimulatorPool {
        return try syncQueue.sync {
            if let existingPool = pools[key] {
                Logger.verboseDebug("Got SimulatorPool for key \(key)")
                return existingPool
            } else {
                let pool = try SimulatorPool(
                    developerDir: key.developerDir,
                    numberOfSimulators: key.numberOfSimulators,
                    testDestination: key.testDestination,
                    tempFolder: tempFolder,
                    simulatorControllerProvider: simulatorControllerProvider
                )
                pools[key] = pool
                Logger.verboseDebug("Created SimulatorPool for key \(key)")
                return pool
            }
        }
    }
    
    public func deleteSimulators() {
        syncQueue.sync {
            for pool in pools.values {
                pool.deleteSimulators()
            }
            pools.removeAll()
        }
    }
}

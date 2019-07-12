import Foundation
import Models
import ResourceLocationResolver
import TemporaryStuff

public final class FbsimctlBasedOnDemandSimulatorPoolProvider {
    private let resourceLocationResolver: ResourceLocationResolver
    private let tempFolder: TemporaryFolder
    
    private var cachedPools = [ResourceLocation: OnDemandSimulatorPool]()
    private let syncQueue = DispatchQueue(label: "FbsimctlBasedOnDemandSimulatorPoolProvider")
    
    public init(
        resourceLocationResolver: ResourceLocationResolver,
        tempFolder: TemporaryFolder
    ) {
        self.resourceLocationResolver = resourceLocationResolver
        self.tempFolder = tempFolder
    }
    
    public func createOnDemandSimulatorPool(
        fbsimctl: ResourceLocation
    ) -> OnDemandSimulatorPool {
        return syncQueue.sync {
            if let cachedPool = cachedPools[fbsimctl] {
                return cachedPool
            }
            
            let resolvableFbsimctl = resourceLocationResolver.resolvable(resourceLocation: fbsimctl)
            
            let pool = LazyCachedOnDemandSimulatorPool(
                resourceLocationResolver: resourceLocationResolver,
                tempFolder: tempFolder,
                simulatorControllerProvider: { (simulator: Simulator) -> (SimulatorController) in
                    return FbsimctlSimulatorController(
                        simulator: simulator,
                        fbsimctl: resolvableFbsimctl
                    )
                }
            )
            cachedPools[fbsimctl] = pool
            return pool
        }
    }
}

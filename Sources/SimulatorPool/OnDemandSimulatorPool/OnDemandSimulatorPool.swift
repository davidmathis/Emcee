import Foundation

public protocol OnDemandSimulatorPool {
    func pool(key: SimulatorPoolKey) throws -> SimulatorPool
    func deleteSimulators()
}

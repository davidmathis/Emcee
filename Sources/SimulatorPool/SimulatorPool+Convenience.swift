import Logging
import Models

public final class AllocatedSimulator {
    public let simulatorInfo: SimulatorInfo
    public let releaseSimulator: () -> ()

    public init(
        simulatorInfo: SimulatorInfo,
        releaseSimulator: @escaping () -> ()
    ) {
        self.simulatorInfo = simulatorInfo
        self.releaseSimulator = releaseSimulator
    }
}

extension SimulatorPool {
    public func allocateSimulator() throws -> AllocatedSimulator {
        let simulatorController = try self.allocateSimulatorController()

        do {
            return AllocatedSimulator(
                simulatorInfo: try simulatorController.bootedSimulator(),
                releaseSimulator: { self.freeSimulatorController(simulatorController) }
            )
        } catch {
            Logger.error("Failed to get booted simulator: \(error)")
            try simulatorController.deleteSimulator()
            throw error
        }
    }
}

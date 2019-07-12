@testable import SimulatorPool
import Models
import ModelsTestHelpers
import PathLib
import TemporaryStuff

public class SimulatorPoolMock: SimulatorPool {
    public init() throws {
        simulatorController = FakeSimulatorController(
            simulator: Shimulator(
                index: 0,
                testDestination: try TestDestination(deviceType: "iPhone XL", runtime: "10.3"),
                workingDirectory: AbsolutePath.root
            ),
            fbsimctl: NonResolvableResourceLocation(),
            developerDir: DeveloperDir.current
        )

        try super.init(
            numberOfSimulators: 1,
            testDestination: TestDestinationFixtures.testDestination,
            fbsimctl: NonResolvableResourceLocation(),
            developerDir: DeveloperDir.current,
            tempFolder: try TemporaryFolder()
        )
    }

    public let simulatorController: FakeSimulatorController
    
    override public func allocateSimulatorController() throws -> FakeSimulatorController {
        return simulatorController
    }

    public var freedSimulator: FakeSimulatorController?
    override public func freeSimulatorController(_ simulator: FakeSimulatorController) {
        freedSimulator = simulator
    }
}

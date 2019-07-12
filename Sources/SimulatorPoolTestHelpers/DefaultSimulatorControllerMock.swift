@testable import SimulatorPool
import Foundation
import Models

public final class DefaultSimulatorControllerMock: DefaultSimulatorController {

    public let simulator: Simulator
    public let fbsimctl: ResolvableResourceLocation
    public let developerDir: DeveloperDir

    public var didCallDelete = false

    public required init(
        simulator: Simulator,
        fbsimctl: ResolvableResourceLocation,
        developerDir: DeveloperDir
    ) {
        self.simulator = simulator
        self.fbsimctl = fbsimctl
        self.developerDir = developerDir

        super.init(
            simulator: simulator,
            fbsimctl: fbsimctl,
            developerDir: developerDir
        )
    }

    public override func bootedSimulator() throws -> Simulator {
        return simulator
    }

    public override func deleteSimulator() throws {
        didCallDelete = true
    }
}

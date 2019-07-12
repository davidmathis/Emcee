import Models
import PathLib
import ResourceLocationResolver
import SimulatorPool
import TemporaryStuff

public final class SimulatorPoolWithDefaultSimulatorControllerMock: SimulatorPool<DefaultSimulatorController> {
    private let testDestination: TestDestination
    private let fbsimctl: ResolvableResourceLocation
    private let resourceLocationResolver = ResourceLocationResolver()

    public init() throws {
        testDestination = try TestDestination(deviceType: "iPhoneXL", runtime: "10.3")
        fbsimctl = resourceLocationResolver.resolvable(
            resourceLocation: .localFilePath("")
        )
        let tempFolder = try TemporaryFolder()


        try super.init(
            numberOfSimulators: 0,
            testDestination: testDestination,
            fbsimctl: fbsimctl,
            developerDir: DeveloperDir.current,
            tempFolder: tempFolder
        )
    }

    override public func allocateSimulatorController() throws -> DefaultSimulatorController {
        return DefaultSimulatorControllerMock(
            simulator: Shimulator.shimulator(
                testDestination: testDestination,
                workingDirectory: AbsolutePath.root
            ),
            fbsimctl: fbsimctl,
            developerDir: DeveloperDir.current
        )
    }
}

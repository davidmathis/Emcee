import AppleTools
import DeveloperDirLocator
import Foundation
import Models
import PathLib
import ResourceLocationResolver
import SimulatorPool
import TemporaryStuff
import fbxctest

public final class DefaultSimulatorControllerProvider: SimulatorControllerProvider {
    
    private let resourceLocationResolver: ResourceLocationResolver
    private let temporaryFolder: TemporaryFolder
    
    public init(
        resourceLocationResolver: ResourceLocationResolver,
        temporaryFolder: TemporaryFolder
    ) {
        self.resourceLocationResolver = resourceLocationResolver
        self.temporaryFolder = temporaryFolder
    }

    public func createSimulatorController(
        developerDir: DeveloperDir,
        developerDirLocator: DeveloperDirLocator,
        simulatorControlTool: SimulatorControlTool,
        testDestination: TestDestination
    ) throws -> SimulatorController {
        let simulatorStateMachineActionExecutor: SimulatorStateMachineActionExecutor
        switch simulatorControlTool {
        case .fbsimctl(let fbsimctlLocation):
            simulatorStateMachineActionExecutor = FbsimctlBasedSimulatorStateMachineActionExecutor(
                fbsimctl: resourceLocationResolver.resolvable(withRepresentable: fbsimctlLocation),
                workingDirectory: try temporaryFolder.pathByCreatingDirectories(
                    components: ["fbsimctl_simulators"]
                )
            )
        case .simctl:
            let defaultSimulatorSetPath = AbsolutePath.userFolder.appending(
                components: ["Library", "Developer", "CoreSimulator", "Devices"]
            )
            simulatorStateMachineActionExecutor = SimctlBasedSimulatorStateMachineActionExecutor(
                simulatorSetPath: defaultSimulatorSetPath
            )
        }
        
        return StateMachineDrivenSimulatorController(
            developerDir: developerDir,
            developerDirLocator: developerDirLocator,
            simulatorStateMachine: SimulatorStateMachine(),
            simulatorStateMachineActionExecutor: simulatorStateMachineActionExecutor,
            testDestination: testDestination
        )
    }
}

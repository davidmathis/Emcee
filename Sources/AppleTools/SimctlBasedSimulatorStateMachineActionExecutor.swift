import DeveloperDirLocator
import Dispatch
import Foundation
import Logging
import Models
import PathLib
import ProcessController
import ResourceLocationResolver
import SimulatorPool

public final class SimctlBasedSimulatorStateMachineActionExecutor: SimulatorStateMachineActionExecutor, CustomStringConvertible {
    private let simulatorSetPath: AbsolutePath
    
    public init(simulatorSetPath: AbsolutePath) {
        self.simulatorSetPath = simulatorSetPath
    }
    
    public var description: String {
        return "simctl"
    }
    
    public func performCreateSimulatorAction(
        environment: [String: String],
        testDestination: TestDestination
    ) throws -> SimulatorInfo {
        let controller = try ProcessController(
            subprocess: Subprocess(
                arguments: [
                    "/usr/bin/xcrun", "simctl",
                    "--set", simulatorSetPath,
                    "create",
                    "Emcee Sim \(testDestination.deviceType) \(testDestination.runtime)",
                    "com.apple.CoreSimulator.SimDeviceType." + testDestination.deviceType.replacingOccurrences(of: " ", with: "."),
                    "com.apple.CoreSimulator.SimRuntime.iOS-" + testDestination.runtime.replacingOccurrences(of: ".", with: "-")
                ],
                environment: environment,
                silenceBehavior: SilenceBehavior(
                    automaticAction: .interruptAndForceKill,
                    allowedSilenceDuration: 30
                )
            )
        )
        controller.startAndListenUntilProcessDies()
        
        let simulatorUuid = try String(
            contentsOf: controller.subprocess.standardStreamsCaptureConfig.stdoutContentsFile.fileUrl,
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return SimulatorInfo(
            simulatorUuid: simulatorUuid,
            simulatorPath: simulatorSetPath.appending(component: simulatorUuid).pathString,
            testDestination: testDestination
        )
    }
    
    public func performBootSimulatorAction(
        environment: [String: String],
        simulatorInfo: SimulatorInfo
    ) throws {
        let processController = try ProcessController(
            subprocess: Subprocess(
                arguments: [
                    "/usr/bin/xcrun", "simctl",
                    "--set", simulatorSetPath,
                    "bootstatus", simulatorInfo.simulatorUuid,
                    "-bd"
                ],
                environment: environment
            )
        )
        processController.startAndListenUntilProcessDies()
    }
    
    public func performShutdownSimulatorAction(
        environment: [String: String],
        simulatorInfo: SimulatorInfo
    ) throws {
        let shutdownController = try ProcessController(
            subprocess: Subprocess(
                arguments: [
                    "/usr/bin/xcrun", "simctl",
                    "--set", simulatorSetPath,
                    "shutdown", simulatorInfo.simulatorUuid
                ],
                environment: environment,
                silenceBehavior: SilenceBehavior(
                    automaticAction: .interruptAndForceKill,
                    allowedSilenceDuration: 20
                )
            )
        )
        shutdownController.startAndListenUntilProcessDies()
    }
    
    public func performDeleteSimulatorAction(
        environment: [String: String],
        simulatorInfo: SimulatorInfo
    ) throws {
        let deleteController = try ProcessController(
            subprocess: Subprocess(
                arguments: [
                    "/usr/bin/xcrun", "simctl",
                    "--set", simulatorSetPath,
                    "delete", simulatorInfo.simulatorUuid
                ],
                environment: environment,
                silenceBehavior: SilenceBehavior(
                    automaticAction: .interruptAndForceKill,
                    allowedSilenceDuration: 15
                )
            )
        )
        deleteController.startAndListenUntilProcessDies()
    }
}

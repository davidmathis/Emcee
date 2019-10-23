import DeveloperDirLocator
import Foundation
import Logging
import Models
import PathLib
import SynchronousWaiter

public final class StateMachineDrivenSimulatorController: SimulatorController {
    private var currentSimulatorState = SimulatorStateMachine.State.absent
    private let developerDir: DeveloperDir
    private let developerDirLocator: DeveloperDirLocator
    private let simulatorStateMachine: SimulatorStateMachine
    private let simulatorStateMachineActionExecutor: SimulatorStateMachineActionExecutor
    private var simulatorInfo: SimulatorInfo?
    private let testDestination: TestDestination
    
    private let maximumBootAttempts = 2
    private static let bootQueue = DispatchQueue(label: "SimulatorBootQueue")

    public init(
        developerDir: DeveloperDir,
        developerDirLocator: DeveloperDirLocator,
        simulatorStateMachine: SimulatorStateMachine,
        simulatorStateMachineActionExecutor: SimulatorStateMachineActionExecutor,
        testDestination: TestDestination
    ) {
        self.developerDir = developerDir
        self.developerDirLocator = developerDirLocator
        self.simulatorStateMachine = simulatorStateMachine
        self.simulatorStateMachineActionExecutor = simulatorStateMachineActionExecutor
        self.testDestination = testDestination
    }
    
    // MARK: - SimulatorController
    
    public func bootedSimulator() throws -> SimulatorInfo {
        try attemptToSwitchState(targetStates: [.booted])
        guard let simulatorInfo = simulatorInfo else {
            throw SimulatorError.unableToLocateSimulatorUuid
        }
        return simulatorInfo
    }

    public func deleteSimulator() throws {
        try attemptToSwitchState(targetStates: [.absent])
    }

    public func shutdownSimulator() throws {
        try attemptToSwitchState(targetStates: [.created, .absent])
    }
    
    // MARK: - State Switching

    private func attemptToSwitchState(targetStates: [SimulatorStateMachine.State]) throws {
        let actions = simulatorStateMachine.actionsToSwitchStates(
            sourceState: currentSimulatorState,
            closestStateFrom: targetStates
        )
        try perform(actions: actions)
    }

    private func perform(actions: [SimulatorStateMachine.Action]) throws {
        for action in actions {
            Logger.debug("Performing action: \(action)")
            switch action {
            case .create:
                try create()
            case .boot:
                try boot()
            case .shutdown:
                try shutdown()
            case .delete:
                try delete()
            }
            currentSimulatorState = action.resultingState
        }
    }
    
    private func create() throws {
        Logger.verboseDebug("Creating simulator: \(testDestination)")

        let simulatorInfo = try simulatorStateMachineActionExecutor.performCreateSimulatorAction(
            environment: try environment(),
            testDestination: testDestination
        )
        Logger.debug("Created simulator \(simulatorInfo)")
        self.simulatorInfo = simulatorInfo
    }
    
    private func boot() throws {
        guard let simulatorInfo = simulatorInfo else {
            throw SimulatorError.unableToLocateSimulatorUuid
        }
        
        Logger.verboseDebug("Booting simulator: \(simulatorInfo)")
        
        let performBoot = {
            try self.simulatorStateMachineActionExecutor.performBootSimulatorAction(
                environment: try self.environment(),
                simulatorInfo: simulatorInfo
            )
        }
        
        try StateMachineDrivenSimulatorController.bootQueue.sync {
            var bootAttempt = 0
            while true {
                do {
                    try performBoot()
                    Logger.debug("Booted simulator \(simulatorInfo) using #\(bootAttempt + 1) attempts")
                    break
                } catch {
                    Logger.error("Attempt to boot simulator \(testDestination.destinationString) failed: \(error)")
                    bootAttempt += 1
                    if bootAttempt < maximumBootAttempts {
                        SynchronousWaiter.wait(timeout: Double(bootAttempt) * 3.0, description: "Time gap between reboot attempts")
                    } else {
                        throw error
                    }
                }
            }
        }

    }
    
    private func shutdown() throws {
        guard let simulatorInfo = simulatorInfo else {
            Logger.warning("Cannot shutdown simulator \(testDestination): simulator not yet created")
            return
        }
        Logger.debug("Shutting down simulator \(simulatorInfo)")
        
        try simulatorStateMachineActionExecutor.performShutdownSimulatorAction(
            environment: try environment(),
            simulatorInfo: simulatorInfo
        )
    }

    private func delete() throws {
        guard let simulatorInfo = simulatorInfo else {
            Logger.warning("Cannot delete simulator \(testDestination): simulator not yet created")
            return
        }
        Logger.debug("Deleting simulator \(simulatorInfo)")
        
        try simulatorStateMachineActionExecutor.performDeleteSimulatorAction(
            environment: try environment(),
            simulatorInfo: simulatorInfo
        )
        
        self.simulatorInfo = nil
        
        try attemptToDeleteSimulatorFiles(
            simulatorInfo: simulatorInfo
        )
    }
    
    private func attemptToDeleteSimulatorFiles(
        simulatorInfo: SimulatorInfo
    ) throws {
        try deleteSimulatorContainer(simulatorInfo: simulatorInfo)
        try deleteSimulatorLogs(simulatorInfo: simulatorInfo)
    }
    
    private func deleteSimulatorLogs(
        simulatorInfo: SimulatorInfo
    ) throws {
        let simulatorLogsPath = ("~/Library/Logs/CoreSimulator/" as NSString)
            .expandingTildeInPath
            .appending(pathComponent: simulatorInfo.simulatorUuid)
        if FileManager.default.fileExists(atPath: simulatorLogsPath) {
            Logger.verboseDebug("Removing logs of simulator \(simulatorInfo)")
            try FileManager.default.removeItem(atPath: simulatorLogsPath)
        } else {
            Logger.verboseDebug("No simulator logs found for \(simulatorInfo)")
        }
    }
    
    private func deleteSimulatorContainer(
        simulatorInfo: SimulatorInfo
    ) throws {
        if FileManager.default.fileExists(atPath: simulatorInfo.simulatorPath) {
            Logger.verboseDebug("Removing files left by simulator \(simulatorInfo)")
            try FileManager.default.removeItem(atPath: simulatorInfo.simulatorPath)
        }
    }

    // MARK: - Envrironment

    private func environment() throws -> [String: String] {
        return [
            "DEVELOPER_DIR": try developerDirLocator.path(developerDir: developerDir).pathString
        ]
    }
    
    // MARK: - Errors
    
    private enum SimulatorError: Error, CustomStringConvertible {
        case unableToLocateSimulatorUuid

        var description: String {
            switch self {
            case .unableToLocateSimulatorUuid:
                return "Failed to obtain simulator's UUID"
            }
        }
    }
}

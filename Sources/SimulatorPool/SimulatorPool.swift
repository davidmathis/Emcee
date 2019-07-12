import Dispatch
import Extensions
import Foundation
import Logging
import Models
import OrderedSet
import ResourceLocationResolver
import TemporaryStuff

/**
 * Every 'borrow' must have a corresponding 'free' call, otherwise the next borrow will throw an error.
 * There is no blocking mechanisms, the assumption is that the callers will use up to numberOfSimulators of threads
 * to borrow and free the simulators.
 */
open class SimulatorPool: CustomStringConvertible {
    private let developerDir: DeveloperDir
    private let numberOfSimulators: UInt
    private let testDestination: TestDestination
    private var controllers: [SimulatorController]
    private var automaticCleanupWorkItem: DispatchWorkItem?
    private let automaticCleanupTiumeout: TimeInterval
    private let syncQueue = DispatchQueue(label: "ru.avito.SimulatorPool")
    private let cleanUpQueue = DispatchQueue(label: "ru.avito.SimulatorPool.cleanup")
    
    public var description: String {
        return "<\(type(of: self)): \(numberOfSimulators)-sim '\(testDestination.deviceType)'+'\(testDestination.runtime)'>"
    }
    
    public init(
        developerDir: DeveloperDir,
        numberOfSimulators: UInt,
        testDestination: TestDestination,
        tempFolder: TemporaryFolder,
        automaticCleanupTiumeout: TimeInterval = 10,
        simulatorControllerProvider: (Simulator) throws -> (SimulatorController)
    ) throws {
        self.developerDir = developerDir
        self.numberOfSimulators = numberOfSimulators
        self.testDestination = testDestination
        self.automaticCleanupTiumeout = automaticCleanupTiumeout
        controllers = try SimulatorPool.createControllers(
            developerDir: developerDir,
            count: numberOfSimulators,
            testDestination: testDestination,
            tempFolder: tempFolder,
            simulatorControllerProvider: simulatorControllerProvider
        )
    }
    
    deinit {
        deleteSimulators()
    }
    
    open func allocateSimulatorController() throws -> SimulatorController {
        return try syncQueue.sync {
            guard !controllers.isEmpty else {
                throw BorrowError.noSimulatorsLeft
            }
            let simulator = controllers.removeLast()
            Logger.verboseDebug("Allocated simulator: \(simulator)")
            cancelAutomaticCleanup()
            return simulator
        }
    }
    
    open func freeSimulatorController(_ simulator: SimulatorController) {
        syncQueue.sync {
            controllers.append(simulator)
            Logger.verboseDebug("Freed simulator: \(simulator)")
            scheduleAutomaticCleanup()
        }
    }
    
    open func deleteSimulators() {
        syncQueue.sync {
            cancelAutomaticCleanup()
            Logger.verboseDebug("\(self): deleting simulators")
            controllers.forEach {
                do {
                    try $0.deleteSimulator()
                } catch {
                    Logger.warning("Failed to delete simulator \($0): \(error). Skipping this error.")
                }
            }
        }
    }
    
    open func shutdownSimulators() {
        syncQueue.sync {
            cancelAutomaticCleanup()
            Logger.verboseDebug("\(self): deleting simulators")
            controllers.forEach {
                do {
                    try $0.shutdownSimulator()
                } catch {
                    Logger.warning("Failed to shutdown simulator \($0): \(error). Skipping this error.")
                }
            }
        }
    }
    
    private static func createControllers(
        developerDir: DeveloperDir,
        count: UInt,
        testDestination: TestDestination,
        tempFolder: TemporaryFolder,
        simulatorControllerProvider: (Simulator) throws -> (SimulatorController)
    ) throws -> [SimulatorController] {
        var result = [SimulatorController]()
        for index in 0 ..< count {
            let folderName = "sim_\(testDestination.deviceType.removingWhitespaces())_\(testDestination.runtime)_\(index)"
            let workingDirectory = try tempFolder.pathByCreatingDirectories(components: [folderName])
            let simulator = Simulator(
                index: index,
                developerDir: developerDir,
                testDestination: testDestination,
                workingDirectory: workingDirectory
            )
            let controller = try simulatorControllerProvider(simulator)
            result.append(controller)
        }
        return result
    }
    
    private func cancelAutomaticCleanup() {
        automaticCleanupWorkItem?.cancel()
        automaticCleanupWorkItem = nil
    }
    
    private func scheduleAutomaticCleanup() {
        cancelAutomaticCleanup()
        
        let cancellationWorkItem = DispatchWorkItem { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.automaticCleanupWorkItem = nil
            if strongSelf.controllers.count == strongSelf.numberOfSimulators {
                Logger.debug("Simulator controllers were not in use for \(strongSelf.automaticCleanupTiumeout) seconds.")
                strongSelf.shutdownSimulators()
            }
        }
        cleanUpQueue.asyncAfter(deadline: .now() + automaticCleanupTiumeout, execute: cancellationWorkItem)
        self.automaticCleanupWorkItem = cancellationWorkItem
    }
}

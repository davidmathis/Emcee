import Foundation
import Models

public protocol SimulatorStateMachineActionExecutor {
    func performCreateSimulatorAction(
        environment: [String: String],
        testDestination: TestDestination
    ) throws -> SimulatorInfo
    
    func performBootSimulatorAction(
        environment: [String: String],
        simulatorInfo: SimulatorInfo
    ) throws
    
    func performShutdownSimulatorAction(
        environment: [String: String],
        simulatorInfo: SimulatorInfo
    ) throws

    func performDeleteSimulatorAction(
        environment: [String: String],
        simulatorInfo: SimulatorInfo
    ) throws
}

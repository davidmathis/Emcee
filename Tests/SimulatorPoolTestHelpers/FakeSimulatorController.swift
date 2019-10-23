import Foundation
import Models
import SimulatorPool

public final class FakeSimulatorController: SimulatorController {
    
    public let simulatorInfo: SimulatorInfo
    public let simulatorControlTool: SimulatorControlTool
    public let developerDir: DeveloperDir
    public var didCallDelete = false
    public var didCallShutdown = false
    
    public init(
        simulatorInfo: SimulatorInfo,
        simulatorControlTool: SimulatorControlTool,
        developerDir: DeveloperDir
    ) {
        self.simulatorInfo = simulatorInfo
        self.simulatorControlTool = simulatorControlTool
        self.developerDir = developerDir
    }
    
    public func bootedSimulator() throws -> SimulatorInfo {
        return simulatorInfo
    }
    
    public func deleteSimulator() throws {
        didCallDelete = true
    }
    
    public func shutdownSimulator() throws {
        didCallShutdown = true
    }
}

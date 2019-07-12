import Foundation
import Models
import SimulatorPool

public final class FakeSimulatorController: SimulatorController {
    
    public let simulator: Simulator
    public let fbsimctl: ResolvableResourceLocation
    public let developerDir: DeveloperDir
    
    public var didCallDelete = false
    public var didCallShutdown = false
    
    public init(simulator: Simulator, fbsimctl: ResolvableResourceLocation, developerDir: DeveloperDir) {
        self.simulator = simulator
        self.fbsimctl = fbsimctl
        self.developerDir = developerDir
    }
    
    public func bootedSimulator() throws -> Simulator {
        return simulator
    }
    
    public func deleteSimulator() throws {
        didCallDelete = true
    }
    
    public func shutdownSimulator() throws {
        didCallShutdown = true
    }
    
    public static func == (l: FakeSimulatorController, r: FakeSimulatorController) -> Bool {
        return l.simulator == r.simulator
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(simulator)
    }
}

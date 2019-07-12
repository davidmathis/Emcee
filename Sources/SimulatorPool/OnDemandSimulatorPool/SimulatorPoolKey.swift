import Foundation
import Models

public final class SimulatorPoolKey: Hashable, CustomStringConvertible {
    public let developerDir: DeveloperDir
    public let numberOfSimulators: UInt
    public let testDestination: TestDestination
    
    public init(
        developerDir: DeveloperDir,
        numberOfSimulators: UInt,
        testDestination: TestDestination
    ) {
        self.developerDir = developerDir
        self.numberOfSimulators = numberOfSimulators
        self.testDestination = testDestination
    }
    
    public var description: String {
        return "<\(type(of: self)): \(numberOfSimulators) simulators, destination: \(testDestination)>"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(developerDir)
        hasher.combine(numberOfSimulators)
        hasher.combine(testDestination)
    }
    
    public static func == (left: SimulatorPoolKey, right: SimulatorPoolKey) -> Bool {
        return left.developerDir == right.developerDir
            && left.numberOfSimulators == right.numberOfSimulators
            && left.testDestination == right.testDestination
    }
}

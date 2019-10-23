import Foundation

public final class SimulatorInfo: Codable, Hashable, CustomStringConvertible {
    
    /// This is simulator's id. Usually this is UUID-like string. `String` type is used to preserve case sensivity information.
    public let simulatorUuid: String
    
    /// Path to a folder containing simulator.
    public let simulatorPath: String
    
    public var simulatorSetPath: String {
        return simulatorPath.deletingLastPathComponent
    }
    
    public let testDestination: TestDestination

    public init(
        simulatorUuid: String,
        simulatorPath: String,
        testDestination: TestDestination
    ) {
        self.simulatorUuid = simulatorUuid
        self.simulatorPath = simulatorPath
        self.testDestination = testDestination
    }
    
    public var description: String {
        return "Simulator \(simulatorUuid) \(testDestination) \(simulatorPath)"
    }
    
    public static func == (left: SimulatorInfo, right: SimulatorInfo) -> Bool {
        return left.simulatorUuid == right.simulatorUuid
            && left.simulatorPath == right.simulatorPath
            && left.testDestination == right.testDestination
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(simulatorUuid)
        hasher.combine(simulatorPath)
        hasher.combine(testDestination)
    }
}

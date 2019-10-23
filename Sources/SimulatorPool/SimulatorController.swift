import Foundation
import Models

public protocol SimulatorController {
    func bootedSimulator() throws -> SimulatorInfo
    func shutdownSimulator() throws
    func deleteSimulator() throws
}

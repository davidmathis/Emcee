import XCTest
import SimulatorPool
import ModelsTestHelpers
import TemporaryStuff
import SimulatorPoolTestHelpers
import SynchronousWaiter

final class SimulatorPoolConvenienceTests: XCTestCase {
    func test__simulator_allocated() throws {
        let pool = try SimulatorPoolMock()
        let allocatedSimulator = try pool.allocateSimulator()

        XCTAssertEqual(
            allocatedSimulator.simulatorInfo,
            SimulatorPoolMock.simulatorController.simulatorInfo
        )
    }

    func test__simulator_contoller_frees__upon_release() throws {
        let pool = try SimulatorPoolMock()
        let allocatedSimulator = try pool.allocateSimulator()
        allocatedSimulator.releaseSimulator()

        XCTAssertEqual(
            allocatedSimulator.simulatorInfo,
            SimulatorPoolMock.simulatorController.simulatorInfo
        )
        
        XCTAssertEqual(
            SimulatorPoolMock.simulatorController.simulatorInfo,
            (pool.freedSimulator as? FakeSimulatorController)?.simulatorInfo
        )
    }
}

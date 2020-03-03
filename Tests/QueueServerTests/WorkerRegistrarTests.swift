import DistWorkerModels
import DistWorkerModelsTestHelpers
import Foundation
import Models
import ModelsTestHelpers
import QueueServer
import QueueServerTestHelpers
import RESTMethods
import WorkerAlivenessProvider
import WorkerAlivenessProviderTestHelpers
import XCTest

final class WorkerRegistrarTests: XCTestCase {
    let alivenessTracker = WorkerAlivenessProviderFixtures.alivenessTrackerWithAlwaysAliveResults()
    let workerConfigurations = WorkerConfigurations()
    let workerDetailsHolder = FakeWorkerDetailsHolder()
    let workerId: WorkerId = "worker_id"
    lazy var registerWorkerPayload = RegisterWorkerPayload(workerId: workerId, workerRestPort: 0)
    
    override func setUp() {
        super.setUp()
        workerConfigurations.add(workerId: workerId, configuration: WorkerConfigurationFixtures.workerConfiguration)
    }
    
    private func createRegistrar() -> WorkerRegistrar {
        return WorkerRegistrar(
            workerConfigurations: workerConfigurations,
            workerAlivenessProvider: alivenessTracker,
            workerDetailsHolder: workerDetailsHolder
        )
    }
    
    func test_registration_for_known_worker() throws {
        let registrar = createRegistrar()
        XCTAssertEqual(alivenessTracker.alivenessForWorker(workerId: workerId).status, .notRegistered)
        
        XCTAssertEqual(
            try registrar.handle(decodedPayload: registerWorkerPayload),
            .workerRegisterSuccess(workerConfiguration: WorkerConfigurationFixtures.workerConfiguration))
        XCTAssertEqual(alivenessTracker.alivenessForWorker(workerId: workerId).status, .alive)
    }
    
    func test___registration_for_blocked_worker__throws() throws {
        let registrar = createRegistrar()
        alivenessTracker.didRegisterWorker(workerId: workerId)
        alivenessTracker.blockWorker(workerId: workerId)
        
        XCTAssertThrowsError(try registrar.handle(decodedPayload: registerWorkerPayload))
    }
    
    func test_successful_registration() throws {
        let registrar = createRegistrar()
        
        let response = try registrar.handle(decodedPayload: registerWorkerPayload)
        XCTAssertEqual(response, .workerRegisterSuccess(workerConfiguration: WorkerConfigurationFixtures.workerConfiguration))
    }
    
    func test_registration_of_unknown_worker() {
        let registrar = createRegistrar()
        XCTAssertThrowsError(try registrar.handle(decodedPayload: RegisterWorkerPayload(workerId: "unknown", workerRestPort: 0)))
    }
}


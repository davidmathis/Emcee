import Dispatch
import DistWorkerModels
import Foundation
import Logging
import Models
import RESTMethods
import RESTServer
import WorkerAlivenessProvider

public final class WorkerRegistrar: RESTEndpoint {
    private let workerConfigurations: WorkerConfigurations
    private let workerAlivenessProvider: WorkerAlivenessProvider
    private let workerDetailsHolder: WorkerDetailsHolder
    
    public enum WorkerRegistrarError: Swift.Error, CustomStringConvertible {
        case missingWorkerConfiguration(workerId: WorkerId)
        case workerIsBlocked(workerId: WorkerId)
        public var description: String {
            switch self {
            case .missingWorkerConfiguration(let workerId):
                return "Missing worker configuration for \(workerId)"
            case .workerIsBlocked(let workerId):
                return "Can't register \(workerId) because it has been blocked"
            }
        }
    }
    
    public init(
        workerConfigurations: WorkerConfigurations,
        workerAlivenessProvider: WorkerAlivenessProvider,
        workerDetailsHolder: WorkerDetailsHolder
    ) {
        self.workerConfigurations = workerConfigurations
        self.workerAlivenessProvider = workerAlivenessProvider
        self.workerDetailsHolder = workerDetailsHolder
    }
    
    public func handle(decodedPayload: RegisterWorkerPayload) throws -> RegisterWorkerResponse {
        guard let workerConfiguration = workerConfigurations.workerConfiguration(workerId: decodedPayload.workerId) else {
            throw WorkerRegistrarError.missingWorkerConfiguration(workerId: decodedPayload.workerId)
        }
        Logger.debug("Registration request from worker with id: \(decodedPayload.workerId)")
        
        let workerAliveness = workerAlivenessProvider.alivenessForWorker(workerId: decodedPayload.workerId)
        switch workerAliveness.status {
        case .notRegistered, .alive, .silent:
            Logger.debug("Worker \(decodedPayload.workerId) has acceptable status")
            workerDetailsHolder.didRegister(
                workerId: decodedPayload.workerId,
                restPort: decodedPayload.workerRestPort
            )
            workerAlivenessProvider.didRegisterWorker(workerId: decodedPayload.workerId)
            return .workerRegisterSuccess(workerConfiguration: workerConfiguration)
        case .blocked:
            Logger.debug("Worker \(decodedPayload.workerId) has blocked status, will return workerIsBlocked")
            throw WorkerRegistrarError.workerIsBlocked(workerId: decodedPayload.workerId)
        }
    }
}

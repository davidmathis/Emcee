import AutomaticTermination
import CurrentlyBeingProcessedBucketsTracker
import DeveloperDirLocator
import Dispatch
import DistWorkerModels
import EventBus
import Foundation
import Logging
import LoggingSetup
import Models
import PathLib
import PluginManager
import QueueClient
import RESTMethods
import RESTServer
import RequestSender
import ResourceLocationResolver
import Runner
import Scheduler
import SimulatorPool
import SynchronousWaiter
import TemporaryStuff
import Timer

public final class DistWorker: SchedulerDelegate {
    private let bucketResultSender: BucketResultSender
    private let callbackQueue = DispatchQueue(label: "DistWorker.callbackQueue", qos: .default, attributes: .concurrent, autoreleaseFrequency: .inherit, target: nil)
    private let currentlyBeingProcessedBucketsTracker = CurrentlyBeingProcessedBucketsTracker()
    private let developerDirLocator: DeveloperDirLocator
    private let onDemandSimulatorPool: OnDemandSimulatorPool
    private let pluginEventBusProvider: PluginEventBusProvider
    private let queueClient: SynchronousQueueClient
    private let resourceLocationResolver: ResourceLocationResolver
    private let syncQueue = DispatchQueue(label: "DistWorker.syncQueue")
    private let temporaryFolder: TemporaryFolder
    private let testRunnerProvider: TestRunnerProvider
    private let workerId: WorkerId
    private let workerRegisterer: WorkerRegisterer
    private var payloadSignature = Either<PayloadSignature, DistWorkerError>.error(DistWorkerError.missingPayloadSignature)
    private var requestIdForBucketId = [BucketId: RequestId]()
    private let restServer = HTTPRESTServer(
        automaticTerminationController: AutomaticTerminationControllerFactory(automaticTerminationPolicy: .stayAlive).createAutomaticTerminationController(),
        portProvider: PortProviderWrapper(provider: { 0 })
    )
    
    private enum BucketFetchResult: Equatable {
        case result(SchedulerBucket?)
        case checkAgain(after: TimeInterval)
    }
    
    public init(
        bucketResultSender: BucketResultSender,
        developerDirLocator: DeveloperDirLocator,
        onDemandSimulatorPool: OnDemandSimulatorPool,
        pluginEventBusProvider: PluginEventBusProvider,
        queueClient: SynchronousQueueClient,
        resourceLocationResolver: ResourceLocationResolver,
        temporaryFolder: TemporaryFolder,
        testRunnerProvider: TestRunnerProvider,
        workerId: WorkerId,
        workerRegisterer: WorkerRegisterer
    ) {
        self.bucketResultSender = bucketResultSender
        self.developerDirLocator = developerDirLocator
        self.onDemandSimulatorPool = onDemandSimulatorPool
        self.pluginEventBusProvider = pluginEventBusProvider
        self.queueClient = queueClient
        self.resourceLocationResolver = resourceLocationResolver
        self.temporaryFolder = temporaryFolder
        self.testRunnerProvider = testRunnerProvider
        self.workerId = workerId
        self.workerRegisterer = workerRegisterer
    }
    
    public func start(
        didFetchAnalyticsConfiguration: @escaping (AnalyticsConfiguration) throws -> (),
        completion: @escaping () -> ()
    ) throws {
        workerRegisterer.registerWithServer(
            workerId: workerId,
            workerRestPort: try startServer(),
            callbackQueue: callbackQueue
        ) { [weak self] result in
            do {
                guard let strongSelf = self else {
                    Logger.error("self is nil in start() in DistWorker")
                    completion()
                    return
                }
                
                let workerConfiguration = try result.dematerialize()
                
                strongSelf.payloadSignature = .success(workerConfiguration.payloadSignature)
                Logger.debug("Registered with server. Worker configuration: \(workerConfiguration)")
                
                try didFetchAnalyticsConfiguration(workerConfiguration.analyticsConfiguration)
                
                _ = try strongSelf.runTests(
                    workerConfiguration: workerConfiguration,
                    onDemandSimulatorPool: strongSelf.onDemandSimulatorPool
                )
                Logger.verboseDebug("Dist worker has finished")
                strongSelf.cleanUpAndStop()
                
                completion()
            } catch {
                Logger.error("Caught unexpected error: \(error)")
                completion()
            }
        }
        
    }
    
    private func startServer() throws -> Int {
        restServer.setHandler(
            pathWithSlash: CurrentlyProcessingBuckets.path.withPrependedSlash,
            handler: RESTEndpointOf(
                actualHandler: CurrentlyProcessingBucketsEndpoint(
                    currentlyBeingProcessedBucketsTracker: currentlyBeingProcessedBucketsTracker
                )
            ),
            requestIndicatesActivity: false
        )
        return try restServer.start()
    }
    
    // MARK: - Private Stuff
    
    private func runTests(
        workerConfiguration: WorkerConfiguration,
        onDemandSimulatorPool: OnDemandSimulatorPool
    ) throws {
        let schedulerCconfiguration = SchedulerConfiguration(
            numberOfSimulators: workerConfiguration.numberOfSimulators,
            onDemandSimulatorPool: onDemandSimulatorPool,
            schedulerDataSource: DistRunSchedulerDataSource(onNextBucketRequest: fetchNextBucket)
        )
        
        let scheduler = Scheduler(
            configuration: schedulerCconfiguration,
            developerDirLocator: developerDirLocator,
            pluginEventBusProvider: pluginEventBusProvider,
            resourceLocationResolver: resourceLocationResolver,
            schedulerDelegate: self,
            tempFolder: temporaryFolder,
            testRunnerProvider: testRunnerProvider
        )
        try scheduler.run()
    }
    
    private func cleanUpAndStop() {
        queueClient.close()
    }
    
    // MARK: - Callbacks
    
    private func nextBucketFetchResult() throws -> BucketFetchResult {
        let requestId = RequestId(value: UUID().uuidString)
        let result = try queueClient.fetchBucket(
            requestId: requestId,
            workerId: workerId,
            payloadSignature: try payloadSignature.dematerialize()
        )
        switch result {
        case .queueIsEmpty:
            Logger.debug("Server returned that queue is empty")
            return .result(nil)
        case .workerHasBeenBlocked:
            Logger.error("Server has blocked this worker")
            return .result(nil)
        case .workerConsideredNotAlive:
            Logger.error("Server considers this worker as not alive")
            return .result(nil)
        case .checkLater(let after):
            Logger.debug("Server asked to wait for \(after) seconds and fetch next bucket again")
            return .checkAgain(after: after)
        case .bucket(let fetchedBucket):
            Logger.debug("Received \(fetchedBucket.bucketId) for \(requestId)")
            currentlyBeingProcessedBucketsTracker.didFetch(bucketId: fetchedBucket.bucketId)
            syncQueue.sync {
                requestIdForBucketId[fetchedBucket.bucketId] = requestId
            }
            return .result(
                SchedulerBucket.from(
                    bucket: fetchedBucket,
                    testExecutionBehavior: TestExecutionBehavior(
                        environment: fetchedBucket.testExecutionBehavior.environment,
                        numberOfRetries: 0
                    )
                )
            )
        }
    }
    
    private func fetchNextBucket() -> SchedulerBucket? {
        while true {
            do {
                Logger.debug("Fetching next bucket from server")
                let fetchResult = try nextBucketFetchResult()
                switch fetchResult {
                case .result(let result):
                    return result
                case .checkAgain(let after):
                    SynchronousWaiter().wait(timeout: after, description: "Pause before checking queue server again")
                }
            } catch {
                Logger.error("Failed to fetch next bucket: \(error)")
                return nil
            }
        }
    }
    
    public func scheduler(
        _ sender: Scheduler,
        obtainedTestingResult testingResult: TestingResult,
        forBucket bucket: SchedulerBucket
    ) {
        Logger.debug("Obtained testingResult: \(testingResult)")
        didReceiveTestResult(testingResult: testingResult)
    }
    
    private func didReceiveTestResult(testingResult: TestingResult) {
        do {
            let requestId: RequestId = try syncQueue.sync {
                guard let requestId = requestIdForBucketId.removeValue(forKey: testingResult.bucketId) else {
                    Logger.error("No requestId for bucket: \(testingResult.bucketId)")
                    throw DistWorkerError.noRequestIdForBucketId(testingResult.bucketId)
                }
                Logger.verboseDebug("Found \(requestId) for bucket \(testingResult.bucketId)")
                return requestId
            }
            
            bucketResultSender.send(
                testingResult: testingResult,
                requestId: requestId,
                workerId: workerId,
                payloadSignature: try payloadSignature.dematerialize(),
                callbackQueue: callbackQueue,
                completion: { [currentlyBeingProcessedBucketsTracker] (result: Either<BucketId, Error>) in
                    defer {
                        currentlyBeingProcessedBucketsTracker.didObtainResult(bucketId: testingResult.bucketId)
                    }
                    
                    do {
                        let acceptedBucketId = try result.dematerialize()
                        guard testingResult.bucketId == acceptedBucketId else {
                            throw DistWorkerError.unexpectedAcceptedBucketId(
                                actual: acceptedBucketId,
                                expected: testingResult.bucketId
                            )
                        }
                        Logger.debug("Successfully sent test run result for bucket \(testingResult.bucketId)")
                    } catch {
                        Logger.error("Server response for results of bucket \(testingResult.bucketId) has error: \(error)")
                    }
                }
            )
        } catch {
            Logger.error("Failed to send test run result for bucket \(testingResult.bucketId): \(error)")
            cleanUpAndStop()
        }
    }
}

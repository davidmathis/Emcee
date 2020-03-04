import AutomaticTermination
import AutomaticTerminationTestHelpers
import BucketQueue
import BucketQueueTestHelpers
import DistWorkerModels
import DistWorkerModelsTestHelpers
import EventBus
import Foundation
import Models
import ModelsTestHelpers
import PortDeterminer
import QueueClient
import QueueModels
import QueueModelsTestHelpers
import QueueServer
import QueueServerTestHelpers
import RESTMethods
import RESTServer
import RESTServerTestHelpers
import RequestSender
import RequestSenderTestHelpers
import ResultsCollector
import ScheduleStrategy
import UniqueIdentifierGeneratorTestHelpers
import Version
import WorkerAlivenessProvider
import WorkerAlivenessProviderTestHelpers
import XCTest

final class QueueHTTPRESTServerTests: XCTestCase {
    let expectedPayloadSignature = PayloadSignature(value: "expectedPayloadSignature")
    let automaticTerminationController = AutomaticTerminationControllerFixture(
        isTerminationAllowed: false
    )
    lazy var restServer = QueueHTTPRESTServer(
        httpRestServer: HTTPRESTServer(
            automaticTerminationController: automaticTerminationController,
            portProvider: PortProviderWrapper { 0 }
        )
    )
    let workerConfigurations = WorkerConfigurations()
    let workerId: WorkerId = "worker"
    let requestId: RequestId = "requestId"
    let jobId: JobId = "JobId"
    lazy var prioritizedJob = PrioritizedJob(jobId: jobId, priority: .medium)
    let stubbedHandler = RESTEndpointOf(actualHandler: FakeRESTEndpoint<Int, Int>(0))
    let callbackQueue = DispatchQueue(label: "callbackQueue")
    
    override func setUp() {
        workerConfigurations.add(workerId: workerId, configuration: WorkerConfigurationFixtures.workerConfiguration)
        automaticTerminationController.indicatedActivityFinished = false
    }
    
    func test__RegisterWorkerHandler() throws {
        let workerRegistrar = WorkerRegistrar(
            workerConfigurations: workerConfigurations,
            workerAlivenessProvider: WorkerAlivenessProviderFixtures.alivenessTrackerWithAlwaysAliveResults(),
            workerDetailsHolder: FakeWorkerDetailsHolder()
        )
        
        restServer.setHandler(
            bucketResultHandler: stubbedHandler,
            dequeueBucketRequestHandler: stubbedHandler,
            jobDeleteHandler: stubbedHandler,
            jobResultsHandler: stubbedHandler,
            jobStateHandler: stubbedHandler,
            registerWorkerHandler: RESTEndpointOf(actualHandler: workerRegistrar),
            scheduleTestsHandler: stubbedHandler,
            versionHandler: stubbedHandler
        )
        
        let workerRegisterer = WorkerRegistererImpl(
            requestSender: RequestSenderFixtures.localhostRequestSender(port: try restServer.start())
        )
        
        let expectation = self.expectation(description: "registerWithServer completion is called")
        
        workerRegisterer.registerWithServer(
            workerId: workerId,
            workerRestPort: 0,
            callbackQueue: callbackQueue
        ) { result in
            do {
                let workerConfiguration = try result.dematerialize()
                
                XCTAssertEqual(
                    workerConfiguration,
                    WorkerConfigurationFixtures.workerConfiguration
                )
            } catch {
                XCTFail("\(error)")
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 15)
        
        XCTAssertTrue(
            automaticTerminationController.indicatedActivityFinished,
            "Should indicate activity to automatic termination controller"
        )
    }
    
    func test__BucketFetchHandler() throws {
        let bucket = BucketFixtures.createBucket(
            testEntries: [
                TestEntryFixtures.testEntry(className: "class1", methodName: "m1"),
                TestEntryFixtures.testEntry(className: "class2", methodName: "m2")
            ]
        )
        let dequeuedBucket = DequeuedBucket(
            enqueuedBucket: EnqueuedBucket(bucket: bucket, enqueueTimestamp: Date(), uniqueIdentifier: UUID().uuidString),
            workerId: workerId,
            requestId: requestId
        )
        let bucketQueue = FakeBucketQueue(fixedDequeueResult: DequeueResult.dequeuedBucket(dequeuedBucket))
        let bucketProvider = BucketProviderEndpoint(
            dequeueableBucketSource: bucketQueue,
            expectedPayloadSignature: expectedPayloadSignature
        )
        
        restServer.setHandler(
            bucketResultHandler: stubbedHandler,
            dequeueBucketRequestHandler: RESTEndpointOf(actualHandler: bucketProvider),
            jobDeleteHandler: stubbedHandler,
            jobResultsHandler: stubbedHandler,
            jobStateHandler: stubbedHandler,
            registerWorkerHandler: stubbedHandler,
            scheduleTestsHandler: stubbedHandler,
            versionHandler: stubbedHandler
        )
        let client = synchronousQueueClient(port: try restServer.start())
        
        XCTAssertEqual(
            try client.fetchBucket(requestId: requestId, workerId: workerId, payloadSignature: expectedPayloadSignature),
            SynchronousQueueClient.BucketFetchResult.bucket(bucket)
        )
        
        XCTAssertFalse(
            automaticTerminationController.indicatedActivityFinished,
            "Should not indicate activity to automatic termination controller"
        )
    }
    
    func test__ResultHandler() throws {
        let alivenessTracker = WorkerAlivenessProviderFixtures.alivenessTrackerWithAlwaysAliveResults()
        let bucketQueue = FakeBucketQueue(throwsOnAccept: false)
        let testingResult = TestingResultFixtures()
            .with(testEntry: TestEntryFixtures.testEntry(className: "class1", methodName: "m1"))
            .addingLostResult()
            .with(testEntry: TestEntryFixtures.testEntry(className: "class2", methodName: "m2"))
            .addingLostResult()
            .testingResult()
        
        let resultHandler = BucketResultRegistrar(
            bucketResultAccepter: bucketQueue,
            expectedPayloadSignature: expectedPayloadSignature,
            workerAlivenessProvider: alivenessTracker
        )
        
        restServer.setHandler(
            bucketResultHandler: RESTEndpointOf(actualHandler: resultHandler),
            dequeueBucketRequestHandler: stubbedHandler,
            jobDeleteHandler: stubbedHandler,
            jobResultsHandler: stubbedHandler,
            jobStateHandler: stubbedHandler,
            registerWorkerHandler: stubbedHandler,
            scheduleTestsHandler: stubbedHandler,
            versionHandler: stubbedHandler
        )
        
        let resultSender = BucketResultSenderImpl(
            requestSender: RequestSenderImpl(
                urlSession: URLSession.shared,
                queueServerAddress: queueServerAddress(port: try restServer.start())
            )
        )
        
        let callbackExpectation = expectation(description: "result sender callback has been invoked")
        resultSender.send(
            testingResult: testingResult,
            requestId: requestId,
            workerId: workerId,
            payloadSignature: expectedPayloadSignature,
            callbackQueue: callbackQueue
        ) { _ in
            callbackExpectation.fulfill()
        }
        wait(for: [callbackExpectation], timeout: 10)
        
        XCTAssertEqual(bucketQueue.acceptedResults, [testingResult])
        
        XCTAssertTrue(
            automaticTerminationController.indicatedActivityFinished,
            "Should indicate activity to automatic termination controller"
        )
    }
    
    func test__QueueServerVersion() throws {
        let versionHandler = FakeRESTEndpoint<QueueVersionPayload, QueueVersionResponse>(QueueVersionResponse.queueVersion("abc"))
        
        restServer.setHandler(
            bucketResultHandler: stubbedHandler,
            dequeueBucketRequestHandler: stubbedHandler,
            jobDeleteHandler: stubbedHandler,
            jobResultsHandler: stubbedHandler,
            jobStateHandler: stubbedHandler,
            registerWorkerHandler: stubbedHandler,
            scheduleTestsHandler: stubbedHandler,
            versionHandler: RESTEndpointOf(actualHandler: versionHandler)
        )
        
        let fetcher = QueueServerVersionFetcherImpl(
            requestSender: RequestSenderImpl(
                urlSession: URLSession(configuration: .default),
                queueServerAddress: queueServerAddress(port: try restServer.start())
            )
        )
        
        let requestFinishedExpectation = expectation(description: "Request processed")
        fetcher.fetchQueueServerVersion(
            callbackQueue: callbackQueue
        ) { result in
            XCTAssertEqual(
                try? result.dematerialize(),
                Version(value: "abc")
            )
            requestFinishedExpectation.fulfill()
        }

        wait(for: [requestFinishedExpectation], timeout: 10.0)
        
        XCTAssertFalse(
            automaticTerminationController.indicatedActivityFinished,
            "Should not indicate activity to automatic termination controller"
        )
    }
    
    func test__schedule_tests() throws {
        let bucketId = BucketId(value: UUID().uuidString)
        let testEntryConfigurations = TestEntryConfigurationFixtures()
            .add(testEntry: TestEntryFixtures.testEntry())
            .testEntryConfigurations()
        let enqueueableBucketReceptor = FakeEnqueueableBucketReceptor()
        let testsEnqueuer = TestsEnqueuer(
            bucketSplitInfo: BucketSplitInfo(
                numberOfWorkers: 0
            ),
            enqueueableBucketReceptor: enqueueableBucketReceptor
        )
        let scheduleTestsEndpoint = ScheduleTestsEndpoint(
            testsEnqueuer: testsEnqueuer,
            uniqueIdentifierGenerator: FixedValueUniqueIdentifierGenerator(value: bucketId.value)
        )
        
        restServer.setHandler(
            bucketResultHandler: stubbedHandler,
            dequeueBucketRequestHandler: stubbedHandler,
            jobDeleteHandler: stubbedHandler,
            jobResultsHandler: stubbedHandler,
            jobStateHandler: stubbedHandler,
            registerWorkerHandler: stubbedHandler,
            scheduleTestsHandler: RESTEndpointOf(actualHandler: scheduleTestsEndpoint),
            versionHandler: stubbedHandler
        )
        let client = synchronousQueueClient(port: try restServer.start())
        
        let acceptedRequestId = try client.scheduleTests(
            prioritizedJob: prioritizedJob,
            scheduleStrategy: .individual,
            testEntryConfigurations: testEntryConfigurations,
            requestId: requestId
        )
        
        XCTAssertEqual(acceptedRequestId, requestId)
        XCTAssertEqual(
            enqueueableBucketReceptor.enqueuedJobs[prioritizedJob],
            [
                BucketFixtures.createBucket(
                    bucketId: bucketId,
                    testEntries: [TestEntryFixtures.testEntry()]
                )
            ]
        )
        
        XCTAssertTrue(
            automaticTerminationController.indicatedActivityFinished,
            "Should indicate activity to automatic termination controller"
        )
    }
    
    func test___job_state() throws {
        let jobState = JobState(
            jobId: jobId,
            queueState: QueueState.running(
                RunningQueueStateFixtures.runningQueueState()
            )
        )
        let jobStateHandler = FakeRESTEndpoint<JobStateRequest, JobStateResponse>(JobStateResponse(jobState: jobState))
        
        restServer.setHandler(
            bucketResultHandler: stubbedHandler,
            dequeueBucketRequestHandler: stubbedHandler,
            jobDeleteHandler: stubbedHandler,
            jobResultsHandler: stubbedHandler,
            jobStateHandler: RESTEndpointOf(actualHandler: jobStateHandler),
            registerWorkerHandler: stubbedHandler,
            scheduleTestsHandler: stubbedHandler,
            versionHandler: stubbedHandler
        )
        let client = synchronousQueueClient(port: try restServer.start())
        
        XCTAssertEqual(
            try client.jobState(jobId: jobId),
            jobState
        )
        
        XCTAssertFalse(
            automaticTerminationController.indicatedActivityFinished,
            "Should not indicate activity to automatic termination controller"
        )
    }
    
    func test___job_results() throws {
        let jobResults = JobResults(jobId: jobId, testingResults: [])
        let jobResultsHandler = FakeRESTEndpoint<JobResultsRequest, JobResultsResponse>(
            JobResultsResponse(jobResults: jobResults)
        )
        
        restServer.setHandler(
            bucketResultHandler: stubbedHandler,
            dequeueBucketRequestHandler: stubbedHandler,
            jobDeleteHandler: stubbedHandler,
            jobResultsHandler: RESTEndpointOf(actualHandler: jobResultsHandler),
            jobStateHandler: stubbedHandler,
            registerWorkerHandler: stubbedHandler,
            scheduleTestsHandler: stubbedHandler,
            versionHandler: stubbedHandler
        )
        let client = synchronousQueueClient(port: try restServer.start())
        XCTAssertEqual(
            try client.jobResults(jobId: jobId),
            jobResults
        )
        
        XCTAssertTrue(
            automaticTerminationController.indicatedActivityFinished,
            "Should indicate activity to automatic termination controller"
        )
    }
    
    func test___deleting_job() throws {
        let jobResultsHandler = FakeRESTEndpoint<JobDeleteRequest, JobDeleteResponse>(
            JobDeleteResponse(jobId: jobId)
        )
        
        restServer.setHandler(
            bucketResultHandler: stubbedHandler,
            dequeueBucketRequestHandler: stubbedHandler,
            jobDeleteHandler: RESTEndpointOf(actualHandler: jobResultsHandler),
            jobResultsHandler: stubbedHandler,
            jobStateHandler: stubbedHandler,
            registerWorkerHandler: stubbedHandler,
            scheduleTestsHandler: stubbedHandler,
            versionHandler: stubbedHandler
        )
        let client = synchronousQueueClient(port: try restServer.start())
        XCTAssertEqual(
            try client.delete(jobId: jobId),
            jobId
        )
        
        XCTAssertTrue(
            automaticTerminationController.indicatedActivityFinished,
            "Should indicate activity to automatic termination controller"
        )
    }
    
    private func queueServerAddress(port: Int) -> SocketAddress {
        return SocketAddress(host: "localhost", port: port)
    }
    
    private func synchronousQueueClient(port: Int) -> SynchronousQueueClient {
        return SynchronousQueueClient(queueServerAddress: queueServerAddress(port: port))
    }
}

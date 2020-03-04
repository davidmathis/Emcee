import AutomaticTermination
import DateProviderTestHelpers
import DistWorkerModels
import DistWorkerModelsTestHelpers
import Foundation
import Models
import ModelsTestHelpers
import PortDeterminer
import QueueClient
import QueueModels
import QueueModelsTestHelpers
import QueueServer
import RequestSender
import ScheduleStrategy
import UniqueIdentifierGeneratorTestHelpers
import VersionTestHelpers
import XCTest
import RequestSenderTestHelpers
import TestHelpers

final class QueueServerTests: XCTestCase {
    private let workerConfigurations = WorkerConfigurations()
    private let workerId: WorkerId = "workerId"
    private let jobId: JobId = "jobId"
    private lazy var prioritizedJob = PrioritizedJob(jobId: jobId, priority: .medium)
    private let automaticTerminationController = AutomaticTerminationControllerFactory(
        automaticTerminationPolicy: .stayAlive
    ).createAutomaticTerminationController()
    /// https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?&page=1
    private let localPortDeterminer = LocalPortDeterminer(portRange: 49152...65535)
    private let bucketSplitInfo = BucketSplitInfoFixtures.bucketSplitInfoFixture()
    private let queueVersionProvider = VersionProviderFixture().buildVersionProvider()
    private let payloadSignature = PayloadSignature(value: "expectedPayloadSignature")

    private let fixedBucketId: BucketId = "fixedBucketId"
    private lazy var uniqueIdentifierGenerator = FixedValueUniqueIdentifierGenerator(
        value: fixedBucketId.value
    )
    private let callbackQueue = DispatchQueue(label: "callbackQueue")

    func test__queue_waits_for_new_workers_and_fails_if_they_not_appear_in_time() {
        workerConfigurations.add(workerId: workerId, configuration: WorkerConfigurationFixtures.workerConfiguration)
        
        let server = QueueServerImpl(
            automaticTerminationController: automaticTerminationController,
            dateProvider: DateProviderFixture(),
            workerConfigurations: workerConfigurations,
            maximumNotReportingDuration: 60,
            checkAgainTimeInterval: .infinity, 
            localPortDeterminer: localPortDeterminer,
            workerAlivenessPolicy: .workersTerminateWhenQueueIsDepleted,
            bucketSplitInfo: bucketSplitInfo,
            queueServerLock: NeverLockableQueueServerLock(),
            queueVersionProvider: queueVersionProvider,
            payloadSignature: payloadSignature,
            requestSenderProvider: DefaultRequestSenderProvider(),
            uniqueIdentifierGenerator: uniqueIdentifierGenerator
        )
        XCTAssertThrowsError(try server.queueResults(jobId: jobId))
    }
    
    func test__queue_returns_results_after_depletion() throws {
        let testEntry = TestEntryFixtures.testEntry(className: "class", methodName: "test")
        let bucket = BucketFixtures.createBucket(
            bucketId: fixedBucketId,
            testEntries: [testEntry]
        )
        let testEntryConfigurations = TestEntryConfigurationFixtures()
            .add(testEntry: testEntry)
            .testEntryConfigurations()
        let testingResult = TestingResultFixtures()
            .with(testEntry: testEntry)
            .with(bucketId: bucket.bucketId)
            .addingLostResult()
            .testingResult()
        
        workerConfigurations.add(workerId: workerId, configuration: WorkerConfigurationFixtures.workerConfiguration)
        let terminationController = AutomaticTerminationControllerFactory(
            automaticTerminationPolicy: .afterBeingIdle(period: 0.1)
        ).createAutomaticTerminationController()
        let server = QueueServerImpl(
            automaticTerminationController: terminationController,
            dateProvider: DateProviderFixture(),
            workerConfigurations: workerConfigurations,
            maximumNotReportingDuration: 60,
            checkAgainTimeInterval: .infinity,
            localPortDeterminer: localPortDeterminer,
            workerAlivenessPolicy: .workersTerminateWhenQueueIsDepleted,
            bucketSplitInfo: bucketSplitInfo,
            queueServerLock: NeverLockableQueueServerLock(),
            queueVersionProvider: queueVersionProvider,
            payloadSignature: payloadSignature,
            requestSenderProvider: DefaultRequestSenderProvider(),
            uniqueIdentifierGenerator: uniqueIdentifierGenerator
        )
        server.schedule(
            bucketSplitter: ScheduleStrategyType.individual.bucketSplitter(
                uniqueIdentifierGenerator: uniqueIdentifierGenerator
            ),
            testEntryConfigurations: testEntryConfigurations,
            prioritizedJob: prioritizedJob
        )
        let queueWaiter = QueueServerTerminationWaiterImpl(
            pollInterval: 0.1,
            queueServerTerminationPolicy: .stayAlive
        )
        
        let expectationForResults = expectation(description: "results became available")
        
        let port = try server.start()
        
        let requestSender = RequestSenderFixtures.localhostRequestSender(port: port)
        let client = synchronousQueueClient(port: port)
        
        let workerRegisterer = WorkerRegistererImpl(requestSender: requestSender)
        
        var actualResults = [JobResults]()
        
        _ = try runSyncronously { [callbackQueue, workerId] completion in
            workerRegisterer.registerWithServer(
                workerId: workerId,
                workerRestPort: 0,
                callbackQueue: callbackQueue
            ) { _ in
                completion(Void())
            }
        }
        
        DispatchQueue.global().async {
            do {
                actualResults.append(
                    try queueWaiter.waitForJobToFinish(
                        queueServer: server,
                        automaticTerminationController: terminationController,
                        jobId: self.jobId
                    )
                )
                expectationForResults.fulfill()
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
        
        let fetchResult = try client.fetchBucket(
            requestId: "request",
            workerId: workerId,
            payloadSignature: payloadSignature
        )
        XCTAssertEqual(fetchResult, SynchronousQueueClient.BucketFetchResult.bucket(bucket))

        let resultSender = BucketResultSenderImpl(
            requestSender: RequestSenderImpl(
                urlSession: URLSession.shared,
                queueServerAddress: queueServerAddress(port: port)
            )
        )
        
        let response: Either<BucketId, Error> = try runSyncronously { [callbackQueue, workerId, payloadSignature] completion in
            resultSender.send(
                testingResult: testingResult,
                requestId: "request",
                workerId: workerId,
                payloadSignature: payloadSignature,
                callbackQueue: callbackQueue,
                completion: completion
            )
        }
        
        XCTAssertEqual(
            try? response.dematerialize(),
            testingResult.bucketId,
            "Server is expected to return a bucket id of accepted testing result"
        )
        
        wait(for: [expectationForResults], timeout: 10)

        XCTAssertEqual(
            [JobResults(jobId: jobId, testingResults: [testingResult])],
            actualResults
        )
    }
    
    private func synchronousQueueClient(port: Int) -> SynchronousQueueClient {
        return SynchronousQueueClient(queueServerAddress: queueServerAddress(port: port))
    }
    
    private func queueServerAddress(port: Int) -> SocketAddress {
        return SocketAddress(host: "localhost", port: port)
    }
}

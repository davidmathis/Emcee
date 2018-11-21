import DistRun
import Foundation
import RESTMethods
import WorkerAlivenessTrackerTestHelpers
import XCTest

final class WorkerAlivenessEndpointTests: XCTestCase {
    func test__handling_requests() {
        let tracker = WorkerAlivenessTrackerFixtures.alivenessTrackerWithAlwaysAliveResults()
        let endpoint = WorkerAlivenessEndpoint(alivenessTracker: tracker)
        XCTAssertNoThrow(try endpoint.handle(decodedRequest: ReportAliveRequest(workerId: "worker")))
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker"), .alive)
    }
    
    func test__worker_is_silent_when_it_does_not_report_within_allowed_timeframe() {
        let tracker = WorkerAlivenessTrackerFixtures.alivenessTrackerWithImmediateTimeout()
        let endpoint = WorkerAlivenessEndpoint(alivenessTracker: tracker)
        XCTAssertNoThrow(try endpoint.handle(decodedRequest: ReportAliveRequest(workerId: "worker")))
        Thread.sleep(forTimeInterval: .leastNonzeroMagnitude)
        XCTAssertEqual(tracker.alivenessForWorker(workerId: "worker"), .silent)
    }
}

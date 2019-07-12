import Foundation
import Models

public final class RuntimeQueryResult {
    public let unavailableTestsToRun: [TestToRun]
    public let availableRuntimeTests: [RuntimeTestEntry]

    public init(
        unavailableTestsToRun: [TestToRun],
        availableRuntimeTests: [RuntimeTestEntry]
    ) {
        self.unavailableTestsToRun = unavailableTestsToRun
        self.availableRuntimeTests = availableRuntimeTests
    }
}

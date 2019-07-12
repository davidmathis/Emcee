import EventBus
import Foundation
import Models
import Runner
import SimulatorPool

public class SchedulerConfiguration {
    public let fbxctestLocation: FbxctestLocation
    public let testRunExecutionBehavior: TestRunExecutionBehavior
    public let testTimeoutConfiguration: TestTimeoutConfiguration
    public let schedulerDataSource: SchedulerDataSource
    public let onDemandSimulatorPool: OnDemandSimulatorPool

    public init(
        fbxctestLocation: FbxctestLocation,
        testRunExecutionBehavior: TestRunExecutionBehavior,
        testTimeoutConfiguration: TestTimeoutConfiguration,
        schedulerDataSource: SchedulerDataSource,
        onDemandSimulatorPool: OnDemandSimulatorPool
    ) {
        self.fbxctestLocation = fbxctestLocation
        self.testRunExecutionBehavior = testRunExecutionBehavior
        self.testTimeoutConfiguration = testTimeoutConfiguration
        self.schedulerDataSource = schedulerDataSource
        self.onDemandSimulatorPool = onDemandSimulatorPool
    }
}

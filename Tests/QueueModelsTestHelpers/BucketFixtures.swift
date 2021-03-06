import BuildArtifacts
import BuildArtifactsTestHelpers
import Foundation
import Models
import ModelsTestHelpers
import QueueModels
import RunnerTestHelpers
import SimulatorPoolTestHelpers

public final class BucketFixtures {
    public static func createBucket(
        bucketId: BucketId = BucketId(value: "BucketFixturesFixedBucketId"),
        testEntries: [TestEntry] = [TestEntryFixtures.testEntry()],
        numberOfRetries: UInt = 0
    ) -> Bucket {
        return Bucket(
            bucketId: bucketId,
            buildArtifacts: BuildArtifactsFixtures.fakeEmptyBuildArtifacts(),
            developerDir: .current,
            pluginLocations: [],
            simulatorControlTool: SimulatorControlToolFixtures.fakeFbsimctlTool,
            simulatorOperationTimeouts: SimulatorOperationTimeoutsFixture().simulatorOperationTimeouts(),
            simulatorSettings: SimulatorSettingsFixtures().simulatorSettings(),
            testDestination: TestDestinationFixtures.testDestination,
            testEntries: testEntries,
            testExecutionBehavior: TestExecutionBehavior(environment: [:], numberOfRetries: numberOfRetries),
            testRunnerTool: TestRunnerToolFixtures.fakeFbxctestTool,
            testTimeoutConfiguration: TestTimeoutConfiguration(singleTestMaximumDuration: 0, testRunnerMaximumSilenceDuration: 0),
            testType: TestType.uiTest
        )
    }
}

import DateProvider
import DateProviderTestHelpers
import Foundation
import WorkerAlivenessProvider

public final class WorkerAlivenessProviderFixtures {
    public static func alivenessTrackerWithAlwaysAliveResults(
        dateProvider: DateProvider = DateProviderFixture()
    ) -> WorkerAlivenessProvider {
        return WorkerAlivenessProviderImpl(
            dateProvider: dateProvider,
            maximumNotReportingDuration: .infinity
        )
    }
    
    public static func alivenessTrackerWithImmediateTimeout(
        dateProvider: DateProvider = DateProviderFixture()
    ) -> WorkerAlivenessProvider {
        return WorkerAlivenessProviderImpl(
            dateProvider: dateProvider,
            maximumNotReportingDuration: 0.0
        )
    }
}

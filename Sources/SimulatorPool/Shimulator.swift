import Foundation
import Models
import PathLib

public final class Shimulator: Simulator {
    public static func shimulator(
        developerDir: DeveloperDir,
        testDestination: TestDestination,
        workingDirectory: AbsolutePath
    ) -> Shimulator {
        return Shimulator(
            index: 0,
            developerDir: developerDir,
            testDestination: testDestination,
            workingDirectory: workingDirectory
        )
    }
}

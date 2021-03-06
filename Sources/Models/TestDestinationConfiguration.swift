import Foundation

public struct TestDestinationConfiguration: Codable {
    public let testDestination: TestDestination
    public let reportOutput: ReportOutput

    public init(testDestination: TestDestination, reportOutput: ReportOutput) {
        self.testDestination = testDestination
        self.reportOutput = reportOutput
    }
}

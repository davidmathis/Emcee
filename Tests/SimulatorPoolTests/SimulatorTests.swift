@testable import SimulatorPool
import Models
import XCTest
import PathLib
import TemporaryStuff

class SimulatorTests: XCTestCase {
    
    var tempFolder: TemporaryFolder!
    var simulatorInfo: SimulatorInfo!
    var testDestination: TestDestination!
    
    let uuid = "C7AFD056-F6BB-4F30-A0C6-B17810EA4B53"
    
    override func setUp() {
        XCTAssertNoThrow(try {
            testDestination = try TestDestination(deviceType: "iPhone X", runtime: "iOS 12.1")
            tempFolder = try TemporaryFolder()
            
            _ = try tempFolder.pathByCreatingDirectories(
                components: [
                    "sim",
                    uuid
                ]
            )
            
            simulatorInfo = SimulatorInfo(
                simulatorUuid: uuid,
                simulatorPath: tempFolder.absolutePath.pathString,
                testDestination: testDestination
            )
        }())
    }
    
    func test___uuid() throws {
        XCTAssertEqual(simulatorInfo.simulatorUuid, uuid)
    }
    
    func test___simulatorSetContainerPath() throws {
        XCTAssertEqual(
            simulatorInfo.simulatorPath,
            tempFolder.absolutePath.pathString
        )
    }
}

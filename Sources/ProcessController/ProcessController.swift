import Foundation
import Logging

public protocol ProcessController: class {
    var subprocess: Subprocess { get }
    var processName: String { get }
    var processId: Int32 { get }
    
    func start()
    func waitForProcessToDie()
    func processStatus() -> ProcessStatus
    
    func writeToStdIn(data: Data) throws
    func terminateAndForceKillIfNeeded()
    func interruptAndForceKillIfNeeded()
    
    func onStdout(listener: @escaping StdoutListener)
    func onStderr(listener: @escaping StderrListener)
    func onSilence(listener: @escaping SilenceListener)
    
    var delegate: ProcessControllerDelegate? { get set }
}

public enum ProcessTerminationError: Error, CustomStringConvertible {
    case unexpectedProcessStatus(pid: Int32, processStatus: ProcessStatus)
    
    public var description: String {
        switch self {
        case .unexpectedProcessStatus(let pid, let status):
            return "Process \(pid) has finished with unexpected status: \(status)"
        }
    }
}

public extension ProcessController {
    func startAndListenUntilProcessDies() {
        start()
        waitForProcessToDie()
    }
    
    var isProcessRunning: Bool {
        return processStatus() == .stillRunning
    }
    
    var subprocessInfo: SubprocessInfo {
        return SubprocessInfo(subprocessId: processId, subprocessName: processName)
    }
    
    func startAndWaitForSuccessfulTermination() throws {
        startAndListenUntilProcessDies()
        let status = processStatus()
        guard status == .terminated(exitCode: 0) else {
            throw ProcessTerminationError.unexpectedProcessStatus(pid: processId, processStatus: status)
        }
    }
}

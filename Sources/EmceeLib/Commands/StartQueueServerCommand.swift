import ArgLib
import AutomaticTermination
import DateProvider
import Deployer
import DistWorkerModels
import Extensions
import Foundation
import LocalHostDeterminer
import LocalQueueServerRunner
import Logging
import LoggingSetup
import Models
import PluginManager
import PortDeterminer
import QueueServer
import RemotePortDeterminer
import RequestSender
import ResourceLocationResolver
import ScheduleStrategy
import TemporaryStuff
import UniqueIdentifierGenerator
import Version

public final class StartQueueServerCommand: Command {
    public let name = "startLocalQueueServer"
    public let description = "Starts queue server on local machine. This mode waits for jobs to be scheduled via REST API."
    public let arguments: Arguments = [
        ArgumentDescriptions.queueServerRunConfigurationLocation.asRequired
    ]
    
    private let localQueueVersionProvider: VersionProvider
    private let payloadSignature: PayloadSignature
    private let requestSenderProvider: RequestSenderProvider
    private let resourceLocationResolver: ResourceLocationResolver
    private let uniqueIdentifierGenerator: UniqueIdentifierGenerator

    public init(
        localQueueVersionProvider: VersionProvider,
        payloadSignature: PayloadSignature,
        requestSenderProvider: RequestSenderProvider,
        resourceLocationResolver: ResourceLocationResolver,
        uniqueIdentifierGenerator: UniqueIdentifierGenerator
    ) {
        self.localQueueVersionProvider = localQueueVersionProvider
        self.payloadSignature = payloadSignature
        self.requestSenderProvider = requestSenderProvider
        self.resourceLocationResolver = resourceLocationResolver
        self.uniqueIdentifierGenerator = uniqueIdentifierGenerator
    }
    
    public func run(payload: CommandPayload) throws {
        let queueServerRunConfiguration = try ArgumentsReader.queueServerRunConfiguration(
            location: try payload.expectedSingleTypedValue(argumentName: ArgumentDescriptions.queueServerRunConfigurationLocation.name),
            resourceLocationResolver: resourceLocationResolver
        )
        
        try LoggingSetup.setupAnalytics(analyticsConfiguration: queueServerRunConfiguration.analyticsConfiguration)
        
        try startQueueServer(
            queueServerRunConfiguration: queueServerRunConfiguration,
            workerDestinations: queueServerRunConfiguration.workerDeploymentDestinations
        )
    }
    
    private func startQueueServer(
        queueServerRunConfiguration: QueueServerRunConfiguration,
        workerDestinations: [DeploymentDestination]
    ) throws {
        Logger.info("Generated payload signature: \(payloadSignature)")
        
        let workerMaximumSilentDuration: TimeInterval = 60.0
        
        let automaticTerminationController = AutomaticTerminationControllerFactory(
            automaticTerminationPolicy: queueServerRunConfiguration.queueServerTerminationPolicy
        ).createAutomaticTerminationController()
        
        let queueServer = QueueServerImpl(
            automaticTerminationController: automaticTerminationController,
            dateProvider: SystemDateProvider(),
            workerConfigurations: createWorkerConfigurations(
                queueServerRunConfiguration: queueServerRunConfiguration
            ),
            maximumNotReportingDuration: workerMaximumSilentDuration,
            checkAgainTimeInterval: queueServerRunConfiguration.checkAgainTimeInterval,
            localPortDeterminer: LocalPortDeterminer(portRange: Ports.defaultQueuePortRange),
            workerAlivenessPolicy: .workersStayAliveWhenQueueIsDepleted,
            bucketSplitInfo: BucketSplitInfo(
                numberOfWorkers: UInt(queueServerRunConfiguration.deploymentDestinationConfigurations.count)
            ),
            queueServerLock: AutomaticTerminationControllerAwareQueueServerLock(
                automaticTerminationController: automaticTerminationController
            ),
            queueVersionProvider: localQueueVersionProvider,
            payloadSignature: payloadSignature,
            requestSenderProvider: requestSenderProvider,
            uniqueIdentifierGenerator: uniqueIdentifierGenerator
        )
        
        let pollPeriod: TimeInterval = 5.0
        let queueServerTerminationWaiter = QueueServerTerminationWaiterImpl(
            pollInterval: pollPeriod,
            queueServerTerminationPolicy: queueServerRunConfiguration.queueServerTerminationPolicy
        )
        
        let localQueueServerRunner = LocalQueueServerRunner(
            queueServer: queueServer,
            automaticTerminationController: automaticTerminationController,
            queueServerTerminationWaiter: queueServerTerminationWaiter,
            queueServerTerminationPolicy: queueServerRunConfiguration.queueServerTerminationPolicy,
            pollPeriod: pollPeriod,
            newWorkerRegistrationTimeAllowance: 360.0,
            versionProvider: localQueueVersionProvider,
            remotePortDeterminer: RemoteQueuePortScanner(
                host: LocalHostDeterminer.currentHostAddress,
                portRange: Ports.defaultQueuePortRange,
                requestSenderProvider: requestSenderProvider
            ),
            temporaryFolder: try TemporaryFolder(),
            workerDestinations: workerDestinations
        )
        try localQueueServerRunner.start()
    }
    
    private func createWorkerConfigurations(
        queueServerRunConfiguration: QueueServerRunConfiguration
    ) -> WorkerConfigurations {
        let configurations = WorkerConfigurations()
        for deploymentDestinationConfiguration in queueServerRunConfiguration.deploymentDestinationConfigurations {
            configurations.add(
                workerId: deploymentDestinationConfiguration.destinationIdentifier,
                configuration: queueServerRunConfiguration.workerConfiguration(
                    deploymentDestinationConfiguration: deploymentDestinationConfiguration,
                    payloadSignature: payloadSignature
                )
            )
        }
        return configurations
    }
}

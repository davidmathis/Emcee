import Foundation
import Deployer
import Extensions
import Models
import PluginManager

public final class DeployablesGenerator {
    let targetAvitoRunnerPath: String
    let auxiliaryPaths: AuxiliaryPaths
    let buildArtifacts: BuildArtifacts
    let environmentFilePath: String
    let targetEnvironmentPath: String
    let simulatorSettings: SimulatorSettings
    let targetSimulatorLocalizationSettingsPath: String
    let targetWatchdogSettingsPath: String

    public init(
        targetAvitoRunnerPath: String,
        auxiliaryPaths: AuxiliaryPaths,
        buildArtifacts: BuildArtifacts,
        environmentFilePath: String,
        targetEnvironmentPath: String,
        simulatorSettings: SimulatorSettings,
        targetSimulatorLocalizationSettingsPath: String,
        targetWatchdogSettingsPath: String)
    {
        self.targetAvitoRunnerPath = targetAvitoRunnerPath
        self.auxiliaryPaths = auxiliaryPaths
        self.buildArtifacts = buildArtifacts
        self.environmentFilePath = environmentFilePath
        self.targetEnvironmentPath = targetEnvironmentPath
        self.simulatorSettings = simulatorSettings
        self.targetSimulatorLocalizationSettingsPath = targetSimulatorLocalizationSettingsPath
        self.targetWatchdogSettingsPath = targetWatchdogSettingsPath
    }
    
    public func deployables() throws -> [PackageName: [DeployableItem]] {
        var deployables =  [PackageName: [DeployableItem]]()
        deployables[.additionalApp] = try additionalAppDeployables()
        deployables[.app] = try appDeployables()
        deployables[.avitoRunner] = [runnerTool()]
        deployables[.environment] = try environmentDeployables()
        deployables[.fbsimctl] = try toolForBinary(location: auxiliaryPaths.fbsimctl, toolName: PackageName.fbsimctl.rawValue)
        deployables[.fbxctest] = try toolForBinary(location: auxiliaryPaths.fbxctest, toolName: PackageName.fbxctest.rawValue)
        deployables[.plugin] = try pluginDeployables()
        deployables[.simulatorLocalizationSettings] = try simulatorLocalizationSettingsDeployables()
        deployables[.testRunner] = try testRunnerDeployables()
        deployables[.watchdogSettings] = try watchdogSettingsDeployables()
        deployables[.xctestBundle] = try xctestDeployables()
        return deployables
    }
    
    func appDeployables() throws -> [DeployableItem] {
        return [
            try DeployableBundle(
                name: PackageName.app.rawValue,
                bundleUrl: URL(fileURLWithPath: buildArtifacts.appBundle))]
    }
    
    func additionalAppDeployables() throws -> [DeployableItem] {
        return try buildArtifacts.additionalApplicationBundles.map {
            let url = URL(fileURLWithPath: $0)
            let name = PackageName.additionalApp.rawValue.appending(
                pathComponent: url.lastPathComponent.deletingPathExtension)
            return try DeployableBundle(name: name, bundleUrl: url)
        }
    }
    
    func xctestDeployables() throws -> [DeployableItem] {
        return [
            try DeployableBundle(
                name: PackageName.xctestBundle.rawValue,
                bundleUrl: URL(fileURLWithPath: buildArtifacts.xcTestBundle))]
    }
    
    func testRunnerDeployables() throws -> [DeployableItem] {
        return [
            try DeployableBundle(
                name: PackageName.testRunner.rawValue,
                bundleUrl: URL(fileURLWithPath: buildArtifacts.runner))]
    }
    
    func environmentDeployables() throws -> [DeployableItem] {
        return [
            DeployableItem(
                name: PackageName.environment.rawValue,
                files: [DeployableFile(source: environmentFilePath, destination: targetEnvironmentPath)])]
    }
    
    func runnerTool() -> DeployableTool {
        let path = ProcessInfo.processInfo.arguments.elementAtIndex(
            0,
            "First launch arg which always set and points to executable")
        return DeployableTool(
            name: PackageName.avitoRunner.rawValue,
            files: [DeployableFile(source: path, destination: targetAvitoRunnerPath)])
    }
    
    func toolForBinary(location: ResourceLocation, toolName: String) throws -> [DeployableTool] {
        switch location {
        case .localFilePath(let binaryPath):
            let parentDirPath = binaryPath.deletingLastPathComponent
            let bundleName = parentDirPath.lastPathComponent
            let url = URL(fileURLWithPath: parentDirPath)
            let files = try DeployableBundle.filesForBundle(bundleUrl: url)
                .filter { file -> Bool in
                    // We remove the bundle directory itself: we do deploy tool with some surrounding files,
                    // so we don't deploy its parent folder
                    file.source != url.path
                }
                .map { (file: DeployableFile) -> DeployableFile in
                    guard let updatedDestination = file.destination.stringWithPathRelativeTo(anchorPath: bundleName) else {
                        throw DeploymentError.failedToRelativizePath(file.destination, anchorPath: bundleName)
                    }
                    return DeployableFile(source: file.source, destination: updatedDestination)
            }
            return [DeployableTool(name: toolName, files: Set(files))]
        case .void:
            return []
        case .remoteUrl:
            return []
        }
    }
    
    func simulatorLocalizationSettingsDeployables() throws -> [DeployableItem] {
        guard let simulatorLocalizationSettings = simulatorSettings.simulatorLocalizationSettings else { return [] }
        return [
            DeployableItem(
                name: PackageName.simulatorLocalizationSettings.rawValue,
                files: [
                    DeployableFile(
                        source: simulatorLocalizationSettings,
                        destination: targetSimulatorLocalizationSettingsPath)])]
    }
    
    func watchdogSettingsDeployables() throws -> [DeployableItem] {
        guard let watchdogSettings = simulatorSettings.watchdogSettings else { return [] }
        return [
            DeployableItem(
                name: PackageName.watchdogSettings.rawValue,
                files: [
                    DeployableFile(
                        source: watchdogSettings,
                        destination: targetWatchdogSettingsPath)])]
    }
    
    func pluginDeployables() throws -> [DeployableItem] {
        return try auxiliaryPaths.plugins.flatMap { location -> [DeployableItem] in
            switch location {
            case .localFilePath(let path):
                let url = URL(fileURLWithPath: path)
                let name = PackageName.plugin.rawValue.appending(
                    pathComponent: url.lastPathComponent.deletingPathExtension)
                return [try DeployableBundle(name: name, bundleUrl: url)]
            case .void:
                return []
            case .remoteUrl:
                return []
            }
        }
    }
}

//
//  Installation Progress Tracker.swift
//  Cork
//
//  Created by David Bureš on 22.02.2023.
//

import CorkShared
import Foundation

class InstallationProgressTracker: ObservableObject
{
    var package: BrewPackage = .init(name: "", type: .formula, installedOn: nil, versions: [], sizeInBytes: 0)
    
    @Published var dependencies: [String] = []
    @Published var fetchedDependencies: Int = 0
    @Published var installedDependencies: Int = 0
    @Published var stage: InstallationStage = .common(.ready)
    @Published var output: [RealTimeTerminalLine] = []
    
    var progress: Double
    {
        switch stage
        {
        case .common(.ready): 0
        case .common: 1
        
        case .formula(.fetchingDependencies): 0
        case .formula(.fetchingDependency): 0.5 * Double(fetchedDependencies)/Double(dependencies.count)
        case .formula(.installingDependencies): 0.5
        case .formula(.installingDependency): 0.5 + 0.5 * Double(installedDependencies)/Double(dependencies.count)
        case .formula(.installing): 1
        
        case .cask(.downloading): 0
        case .cask(.installing): 0.33
        case .cask(.moving): 0.67
        case .cask(.linking): 1
        }
    }

    private var showRealTimeTerminalOutputs: Bool
    {
        UserDefaults.standard.bool(forKey: "showRealTimeTerminalOutputOfOperations")
    }

    @MainActor
    func installPackage(using brewData: BrewDataStorage, cachedPackagesTracker: CachedPackagesTracker) async throws -> TerminalOutput
    {
        AppConstants.shared.logger.debug("Installing package \(self.package.name, privacy: .auto)")

        var installationResult: TerminalOutput = .init(standardOutput: "", standardError: "")
        
        let brewArguments: [String] = switch self.package.type
        {
        case .formula: ["install", package.name]
        case .cask: ["install", "--no-quarantine", package.name]
        }
        
        for await streamedOutput in shell(AppConstants.shared.brewExecutablePath, brewArguments)
        {
            switch streamedOutput
            {
            case .standardOutput(let outputLines):
                for outputLine in outputLines.components(separatedBy: "\n")
                {
                    AppConstants.shared.logger.debug("Package install line out: \(outputLine, privacy: .public)")

                    output.append(RealTimeTerminalLine(line: outputLine))
                    
                    if let newStage = InstallationStage.match(
                        outputLine,
                        packageName: package.name,
                        dependencies: dependencies,
                        type: package.type,
                        currentStage: stage
                    )
                    {
                        self.stage = newStage
                        AppConstants.shared.logger.debug("Installation stage: \(self.stage, privacy: .public)")
                        switch stage
                        {
                        case .formula(.fetchingDependencies(let foundDependencies)):
                            dependencies = foundDependencies
                        case .formula(.fetchingDependency):
                            fetchedDependencies += 1
                        case .formula(.installingDependency):
                            installedDependencies += 1
                        default:
                            break
                        }
                    }
                    
                }
            case .standardError(let errorLines):
                AppConstants.shared.logger.error("Errored out: \(errorLines, privacy: .public)")
                
                output.append(RealTimeTerminalLine(line: errorLines))
                
                if let newStage = InstallationStage.match(
                    errorLines,
                    packageName: package.name,
                    dependencies: dependencies,
                    type: package.type,
                    currentStage: stage
                )
                {
                    stage = newStage
                }
            }
        }
        
        installationResult.standardOutput.append(output.map{$0.line}.joined(separator: "\n"))
        
        stage = .common(.finished)

        do
        {
            try await brewData.synchronizeInstalledPackages(cachedPackagesTracker: cachedPackagesTracker)
        }
        catch let synchronizationError
        {
            AppConstants.shared.logger.error("Package isntallation function failed to synchronize packages: \(synchronizationError.localizedDescription)")
        }

        return installationResult
    }
}

// MARK: - Installation Stages

enum InstallationStage: Comparable
{
    case common(CommonInstallationStage)
    case formula(FormulaInstallationStage)
    case cask(CaskInstallationStage)
    
    var ordinality: Int
    {
        switch self
        {
        case .common(.ready): .min
        case .common(.requiresSudoPassword): .max
        case .common(.finished): .max
        case .common(.binaryAlreadyExists): .max
        case .common(.wrongArchitecture): .max
        case .common(.terminatedUnexpectedly): .max
            
        case .formula(.fetchingDependencies): 0
        case .formula(.fetchingDependency): 1
        case .formula(.installingDependencies): 2
        case .formula(.installingDependency): 3
        case .formula(.installing): 4
            
        case .cask(.downloading): 0
        case .cask(.installing): 1
        case .cask(.moving): 2
        case .cask(.linking): 3
        }
    }
    
    static func < (lhs: InstallationStage, rhs: InstallationStage) -> Bool
    {
        lhs.ordinality < rhs.ordinality
    }

    static func match(_ line: String, packageName: String, dependencies: [String], type: PackageType, currentStage: InstallationStage) -> InstallationStage?
    {
        if let commonStage = CommonInstallationStage.match(line)
        {
            return max(.common(commonStage), currentStage)
        }
        
        switch type
        {
        case .formula:
            if let formulaStage = FormulaInstallationStage.match(line, packageName: packageName, dependencies: dependencies)
            {
                return max(currentStage, .formula(formulaStage))
            }
        case .cask:
            if let caskStage = CaskInstallationStage.match(line)
            {
                return max(currentStage, .cask(caskStage))
            }
        }
        
        return nil
    }
}

extension InstallationStage: CustomStringConvertible
{
    var description: String
    {
        switch self
        {
        case .common(.ready): "Ready"
        case .common(.requiresSudoPassword): "Requires Sudo Password"
        case .common(.finished): "Finished"
        case .common(.binaryAlreadyExists): "Binary Already Exists"
        case .common(.wrongArchitecture): "Wrong Architecture"
        case .common(.terminatedUnexpectedly): "Terminated Unexpectedly"
            
        case .formula(.fetchingDependencies): "Fetching Formula Dependencies"
        case .formula(.fetchingDependency(let dependency)): "Fetching Formula Dependency: \(dependency)"
        case .formula(.installingDependencies): "Installing Formula Dependencies"
        case .formula(.installingDependency(let dependency)): "Installing Formula Dependency: \(dependency)"
        case .formula(.installing): "Installing Formula"
            
        case .cask(.downloading): "Downloading Cask"
        case .cask(.installing): "Installing Cask"
        case .cask(.moving): "Moving Cask"
        case .cask(.linking): "Linking Binary"
        }
    }
}

enum CommonInstallationStage: Equatable
{
    case ready
    case requiresSudoPassword
    case finished
    case binaryAlreadyExists
    case wrongArchitecture
    case terminatedUnexpectedly
    
    static func match(_ line: String) -> CommonInstallationStage?
    {
        if line.contains("password is required")
        {
            return .requiresSudoPassword
        }
        if line.contains("was successfully installed")
        {
            return .finished
        }
        if line.contains("there is already an App at")
        {
            return .binaryAlreadyExists
        }
        if line.contains("depends on hardware architecture being")
            && line.contains("but you are running")
        {
            return .wrongArchitecture
        }
        return nil
    }
}

enum FormulaInstallationStage: Equatable
{
    case fetchingDependencies([String])
    case fetchingDependency(String)
    case installingDependencies([String])
    case installingDependency(String)
    case installing
    
    private static func getDependencyNames(from line: String, packageName: String) -> [String] {
        let match: String? = try? line.regexMatch("(?<=\(packageName): ).*?(.*)")
        return match?.replacingOccurrences(of: " and", with: ",").components(separatedBy: ", ") ?? []
    }
    
    static func match(_ line: String, packageName: String, dependencies: [String]) -> FormulaInstallationStage?
    {
        if line.contains("==> Fetching dependencies for \(packageName):")
        {
            return .fetchingDependencies(getDependencyNames(from: line, packageName: packageName))
        }
        
        for dependency in dependencies
        {
            if line.contains("==> Fetching \(dependency)")
            {
                return .fetchingDependency(dependency)
            }
        }
        
        if line.contains("==> Installing dependencies for \(packageName):")
        {
            return .installingDependencies(getDependencyNames(from: line, packageName: packageName))
        }
        
        for dependency in dependencies {
            if line.contains("==> Installing \(packageName) dependency: \(dependency)")
            {
                return .installingDependency(dependency)
            }
        }
        
        if line.contains("==> Installing \(packageName)")
        {
            return .installing
        }
        
        return nil
    }
}

enum CaskInstallationStage: Equatable
{
    case downloading
    case installing
    case moving
    case linking
    
    static func match(_ line: String) -> CaskInstallationStage?
    {
        if line.contains("==> Downloading")
        {
            return .downloading
        }
        
        if line.contains("==> Installing Cask")
            || line.contains("==> Purging files")
        {
            return .installing
        }
        
        if line.contains("==> Moving App")
        {
            return .moving
        }
        
        if line.contains("==> Linking binary")
        {
            return .linking
        }
        
        return nil
    }
}

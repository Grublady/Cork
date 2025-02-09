//
//  Installing.swift
//  Cork
//
//  Created by David Bureš on 29.09.2023.
//

import SwiftUI
import CorkShared

struct InstallingPackageView: View
{
    @Environment(\.dismiss) var dismiss: DismissAction

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var brewData: BrewDataStorage
    
    @EnvironmentObject var cachedPackagesTracker: CachedPackagesTracker

    @ObservedObject var installationProgressTracker: InstallationProgressTracker

    @Binding var packageInstallationProcessStep: PackageInstallationProcessSteps

    @State var isShowingRealTimeOutput: Bool = false

    var body: some View
    {
        VStack(alignment: .leading)
        {
            if installationProgressTracker.stage != .common(.finished)
            {
                ProgressView(value: installationProgressTracker.progress)
                {
                    VStack(alignment: .leading)
                    {
                        switch installationProgressTracker.stage
                        {
                        case .common(.ready):
                            Text("add-package.install.ready")

                        case .formula(.fetchingDependencies), .formula(.fetchingDependency):
                            Text("add-package.install.fetching-dependencies")
                            
                        case .formula(.installingDependencies), .formula(.installingDependency):
                            Text("add-package.install.installing-dependencies-\(installationProgressTracker.installedDependencies)-of-\(installationProgressTracker.dependencies.count)")

                        case .formula(.installing):
                            Text("add-package.install.installing-package")

                        case .common(.finished):
                            Text("add-package.install.finished")

                        case .cask(.downloading):
                            Text("add-package.install.downloading-cask-\(installationProgressTracker.package.name)")

                        case .cask(.installing):
                            Text("add-package.install.installing-cask-\(installationProgressTracker.package.name)")

                        case .cask(.linking):
                            Text("add-package.install.linking-cask-binary")

                        case .cask(.moving):
                            Text("add-package.install.moving-cask-\(installationProgressTracker.package.name)")

                        case .common(.requiresSudoPassword):
                            Text("add-package.install.requires-sudo-password-\(installationProgressTracker.package.name)")
                                .onAppear
                                {
                                    packageInstallationProcessStep = .requiresSudoPassword
                                }

                        case .common(.wrongArchitecture):
                            Text("add-package.install.wrong-architecture.title")
                                .onAppear
                                {
                                    packageInstallationProcessStep = .wrongArchitecture
                                }

                        case .common(.binaryAlreadyExists):
                            Text("add-package.install.binary-already-exists-\(installationProgressTracker.package.name)")
                                .onAppear
                                {
                                    packageInstallationProcessStep = .binaryAlreadyExists
                                }

                        case .common(.terminatedUnexpectedly):
                            Text("add-package.install.installation-terminated.title")
                                .onAppear
                                {
                                    packageInstallationProcessStep = .installationTerminatedUnexpectedly
                                }
                        }
                        LiveTerminalOutputView(
                            lineArray: $installationProgressTracker.output,
                            isRealTimeTerminalOutputExpanded: $isShowingRealTimeOutput
                        )
                    }
                    .fixedSize()
                }
                .allAnimationsDisabled()
            }
            else
            { // Show this when the installation is finished
                Text("add-package.install.finished")
                    .onAppear
                    {
                        packageInstallationProcessStep = .finished
                    }
            }
        }
        .task
        {
            do
            {
                let installationResult: TerminalOutput = try await installationProgressTracker.installPackage(
                    using: brewData,
                    cachedPackagesTracker: cachedPackagesTracker
                )
                
                AppConstants.shared.logger.debug("Installation result:\nStandard output: \(installationResult.standardOutput, privacy: .public)\nStandard error: \(installationResult.standardError, privacy: .public)")

                /// Check if the package installation stag at the end of the install process was something unexpected. Normal package installations go through multiple steps, and the three listed below are not supposed to be the end state. This means that something went wrong during the installation
                switch installationProgressTracker.stage {
                case .common(.finished):
                    break
                default:
                    AppConstants.shared.logger.warning("The installation process quit before it was supposed to")
                    installationProgressTracker.stage = .common(.terminatedUnexpectedly)
                }
            }
            catch let fatalInstallationError
            {
                AppConstants.shared.logger.error("Fatal error occurred during installing a package: \(fatalInstallationError, privacy: .public)")

                dismiss()

                appState.showAlert(errorToShow: .fatalPackageInstallationError(fatalInstallationError.localizedDescription))
            }
        }
    }
}

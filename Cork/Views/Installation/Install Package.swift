//
//  Add Package.swift
//  Cork
//
//  Created by David Bureš on 03.07.2022.
//

import CorkNotifications
import CorkShared
import SwiftUI

struct AddFormulaView: View
{
    @Environment(\.dismiss) var dismiss: DismissAction

    @State private var packageRequested: String = ""

    @EnvironmentObject var brewData: BrewDataStorage
    @EnvironmentObject var appState: AppState

    @EnvironmentObject var cachedDownloadsTracker: CachedPackagesTracker

    @State private var foundPackageSelection: UUID? = nil

    @ObservedObject var searchResultTracker: SearchResultTracker = .init()
    @ObservedObject var installationProgressTracker: InstallationProgressTracker = .init()

    @State var packageInstallationProcessStep: PackageInstallationProcessSteps = .ready

    @State var packageInstallTrackingNumber: Float = 0

    @FocusState var isSearchFieldFocused: Bool

    @AppStorage("showPackagesStillLeftToInstall") var showPackagesStillLeftToInstall: Bool = false
    @AppStorage("notifyAboutPackageInstallationResults") var notifyAboutPackageInstallationResults: Bool = false

    var shouldShowSheetTitle: Bool
    {
        [.ready, .presentingSearchResults].contains(packageInstallationProcessStep)
    }
    
    var isDismissable: Bool
    {
        [.ready, .presentingSearchResults, .fatalError, .anotherProcessAlreadyRunning].contains(packageInstallationProcessStep)
    }

    var sheetTitle: LocalizedStringKey
    {
        switch packageInstallationProcessStep
        {
        case .ready:
            return "add-package.title"
        case .searching:
            return ""
        case .presentingSearchResults:
            return "add-package.title"
        case .installing:
            return ""
        case .finished:
            return ""
        case .fatalError:
            return ""
        case .requiresSudoPassword:
            return ""
        case .wrongArchitecture:
            return ""
        case .binaryAlreadyExists:
            return ""
        case .anotherProcessAlreadyRunning:
            return ""
        case .installationTerminatedUnexpectedly:
            return ""
        }
    }

    var body: some View
    {
        NavigationStack
        {
            SheetTemplate(isShowingTitle: shouldShowSheetTitle)
            {
                Group
                {
                    switch packageInstallationProcessStep
                    {
                    case .ready:
                        InstallationInitialView(
                            searchResultTracker: searchResultTracker,
                            packageRequested: $packageRequested,
                            foundPackageSelection: $foundPackageSelection,
                            installationProgressTracker: installationProgressTracker,
                            packageInstallationProcessStep: $packageInstallationProcessStep
                        )

                    case .searching:
                        InstallationSearchingView(
                            packageRequested: $packageRequested,
                            searchResultTracker: searchResultTracker,
                            packageInstallationProcessStep: $packageInstallationProcessStep
                        )

                    case .presentingSearchResults:
                        PresentingSearchResultsView(
                            searchResultTracker: searchResultTracker,
                            packageRequested: $packageRequested,
                            foundPackageSelection: $foundPackageSelection,
                            packageInstallationProcessStep: $packageInstallationProcessStep,
                            installationProgressTracker: installationProgressTracker
                        )

                    case .installing:
                        InstallingPackageView(
                            installationProgressTracker: installationProgressTracker,
                            packageInstallationProcessStep: $packageInstallationProcessStep
                        )

                    case .finished:
                        DisappearableSheet
                        {
                            ComplexWithIcon(systemName: "checkmark.seal")
                            {
                                HeadlineWithSubheadline(
                                    headline: "add-package.finished",
                                    subheadline: "add-package.finished.description",
                                    alignment: .leading
                                )
                            }
                        }
                        .onAppear
                        {
                            cachedDownloadsTracker.cachedDownloadsFolderSize = AppConstants.shared.brewCachedDownloadsPath.directorySize

                            if notifyAboutPackageInstallationResults
                            {
                                sendNotification(title: String(localized: "notification.install-finished"))
                            }
                        }

                    case .fatalError: /// This shows up when the function for executing the install action throws an error
                        InstallationFatalErrorView(installationProgressTracker: installationProgressTracker)

                    case .requiresSudoPassword:
                        SudoRequiredView(installationProgressTracker: installationProgressTracker)

                    case .wrongArchitecture:
                        WrongArchitectureView(installationProgressTracker: installationProgressTracker)

                    case .binaryAlreadyExists:
                        BinaryAlreadyExistsView(installationProgressTracker: installationProgressTracker)

                    case .anotherProcessAlreadyRunning:
                        AnotherProcessAlreadyRunningView()

                    case .installationTerminatedUnexpectedly:
                        InstallationTerminatedUnexpectedlyView(terminalOutputOfTheInstallation: installationProgressTracker.packageBeingInstalled.realTimeTerminalOutput)
                    }
                }
                .navigationTitle(sheetTitle)
                .toolbar
                {
                    if isDismissable
                    {
                        ToolbarItem(placement: .cancellationAction)
                        {
                            Button
                            {
                                dismiss()
                            } label: {
                                Text("action.cancel")
                            }
                            .keyboardShortcut(.cancelAction)
                        }
                    }
                }
            }
        }
        .onDisappear
        {
            cachedDownloadsTracker.assignPackageTypeToCachedDownloads(brewData: brewData)
        }
    }
}

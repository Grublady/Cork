//
//  Ready View.swift
//  Cork
//
//  Created by David Bureš on 25.02.2023.
//

import CorkShared
import SwiftUI

struct MaintenanceReadyView: View
{
    @AppStorage("default_shouldUninstallOrphans") var default_shouldUninstallOrphans: Bool = true
    @AppStorage("default_shouldPurgeCache") var default_shouldPurgeCache: Bool = true
    @AppStorage("default_shouldDeleteDownloads") var default_shouldDeleteDownloads: Bool = true
    @AppStorage("default_shouldPerformHealthCheck") var default_shouldPerformHealthCheck: Bool = false

    @Binding var shouldUninstallOrphans: Bool
    @Binding var shouldPurgeCache: Bool
    @Binding var shouldDeleteDownloads: Bool
    @Binding var shouldPerformHealthCheck: Bool

    @Binding var maintenanceSteps: MaintenanceSteps

    @State var isShowingControlButtons: Bool

    @State var forcedOptions: Bool

    var enablePadding: Bool = true

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            Form
            {
                LabeledContent("maintenance.steps.packages")
                {
                    VStack(alignment: .leading)
                    {
                        Toggle(isOn: $shouldUninstallOrphans)
                        {
                            Text("maintenance.steps.packages.uninstall-orphans")
                        }
                    }
                }

                LabeledContent("maintenance.steps.downloads")
                {
                    VStack(alignment: .leading)
                    {
                        Toggle(isOn: $shouldPurgeCache)
                        {
                            Text("maintenance.steps.downloads.purge-cache")
                        }
                        Toggle(isOn: $shouldDeleteDownloads)
                        {
                            Text("maintenance.steps.downloads.delete-cached-downloads")
                        }
                    }
                }

                LabeledContent("maintenance.steps.other")
                {
                    Toggle(isOn: $shouldPerformHealthCheck)
                    {
                        Text("maintenance.steps.other.health-check")
                    }
                }
            }
        }
        .toolbar
        {
            if isShowingControlButtons
            {
                ToolbarItem(placement: .primaryAction)
                {
                    Button
                    {
                        AppConstants.shared.logger.debug("Start")

                        maintenanceSteps = .maintenanceRunning
                    } label: {
                        Text("maintenance.steps.start")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isStartDisabled)
                }
            }
        }
        .onAppear
        {
            if !forcedOptions
            {
                /// Replace the provided values with those from AppStorage
                /// I have to do this because I don't want the settings in the sheet itself to affect those in the defaults
                shouldUninstallOrphans = default_shouldUninstallOrphans
                shouldPurgeCache = default_shouldPurgeCache
                shouldDeleteDownloads = default_shouldDeleteDownloads
                shouldPerformHealthCheck = default_shouldPerformHealthCheck
            }
        }
    }

    private var isStartDisabled: Bool
    {
        [shouldUninstallOrphans, shouldPurgeCache, shouldDeleteDownloads, shouldPerformHealthCheck].allSatisfy
        {
            !$0
        }
    }
}

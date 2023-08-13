//
//  Notifications Pane.swift
//  Cork
//
//  Created by David Bureš on 13.08.2023.
//

import SwiftUI
import UserNotifications

struct NotificationsPane: View
{
    @AppStorage("areNotificationsEnabled") var areNotificationsEnabled: Bool = false
    @AppStorage("outdatedPackageNotificationType") var outdatedPackageNotificationType: OutdatedPackageNotificationType = .badge
    
    @AppStorage("notifyAboutPackageUpgradeResults") var notifyAboutPackageUpgradeResults: Bool = false
    
    @EnvironmentObject var appState: AppState

    var body: some View
    {
        SettingsPaneTemplate
        {
            VStack(alignment: .center, spacing: 10)
            {
                VStack(alignment: .center, spacing: 5)
                {
                    Toggle(isOn: $areNotificationsEnabled, label: {
                        Text("settings.notifications.enable-notifications")
                    })
                    .toggleStyle(.switch)
                    .task
                    {
                        await appState.requestNotificationAuthorization()
                        if appState.notificationStatus?.authorizationStatus == .denied || appState.forcedDenyBySystemSettings
                        {
                            areNotificationsEnabled = false
                        }
                    }
                    .onChange(of: areNotificationsEnabled, perform: { newValue in
                        Task(priority: .background) {
                            await appState.requestNotificationAuthorization()
                            if appState.notificationStatus?.authorizationStatus == .denied || appState.forcedDenyBySystemSettings
                            {
                                areNotificationsEnabled = false
                            }
                        }
                    })
                    .disabled(appState.notificationStatus?.authorizationStatus == .denied)
                    
                    if appState.notificationStatus?.authorizationStatus == .denied
                    {
                        Text("settings.notifications.notifications-disabled-in-settings.tooltip")
                            .font(.caption)
                            .foregroundColor(Color(nsColor: NSColor.systemGray))
                    }
                }
                
                Divider()
                
                Form
                {
                    Picker(selection: $outdatedPackageNotificationType) {
                        Text("settings.notifications.outdated-package-notification-type.badge")
                            .tag(OutdatedPackageNotificationType.badge)
                        
                        Text("settings.notifications.outdated-package-notification-type.notification")
                            .tag(OutdatedPackageNotificationType.notification)
                        
                        Text("settings.notifications.outdated-package-notification-type.both")
                            .tag(OutdatedPackageNotificationType.both)
                        
                        Divider()
                        
                        Text("settings.notifications.outdated-package-notification-type.none")
                            .tag(OutdatedPackageNotificationType.none)
                    } label: {
                        Text("settings.notifications.outdated-package-notification-type")
                    }
                    
                    LabeledContent {
                        Toggle(isOn: $notifyAboutPackageUpgradeResults, label: {
                            Text("settings.notifications.notify-about-upgrade-result")
                        })
                    } label: {
                        Text("settings.notifications.notify-about-various-actions")
                    }

                }
                .disabled(!areNotificationsEnabled)
            }
        }
    }
}

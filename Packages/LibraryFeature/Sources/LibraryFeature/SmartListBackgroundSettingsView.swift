//
//  SmartListBackgroundSettingsView.swift
//  LibraryFeature
//
//  UI for configuring smart list background refresh settings
//

import SwiftUI
import CoreModels
import Persistence
import SharedUtilities

// MARK: - Background Settings View

/// View for configuring smart list background refresh settings
public struct SmartListBackgroundSettingsView: View {
    
    @ObservedObject private var backgroundManager: DefaultSmartListBackgroundManager
    @State private var configuration: SmartListRefreshConfiguration
    @State private var showingAdvancedSettings = false
    @State private var showingPerformanceMetrics = false
    
    public init(backgroundManager: DefaultSmartListBackgroundManager) {
        self.backgroundManager = backgroundManager
        // Initialize with current configuration - will be updated in onAppear
        self._configuration = State(initialValue: SmartListRefreshConfiguration())
    }
    
    public var body: some View {
        NavigationView {
            Form {
                mainSettingsSection
                intervalSettingsSection
                advancedSettingsSection
                performanceSection
                actionsSection
            }
            .navigationTitle("Smart List Automation")
            .platformNavigationBarTitleDisplayMode(.large)
            .task {
                configuration = await backgroundManager.configuration
            }
        }
    }
    
    // MARK: - Section Views
    
    private var mainSettingsSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Background Refresh")
                        .font(.headline)
                    Text("Automatically update smart lists in the background")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(
                    get: { configuration.isEnabled },
                    set: { enabled in
                        configuration = SmartListRefreshConfiguration(
                            isEnabled: enabled,
                            globalInterval: configuration.globalInterval,
                            maxRefreshPerCycle: configuration.maxRefreshPerCycle,
                            refreshOnForeground: configuration.refreshOnForeground,
                            refreshOnNetworkChange: configuration.refreshOnNetworkChange
                        )
                        Task {
                            await backgroundManager.updateConfiguration(configuration)
                        }
                    }
                ))
            }
            
            if backgroundManager.isActive {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Background refresh is active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let lastRefresh = backgroundManager.lastRefreshTime {
                        Text("Last: \(lastRefresh, style: .relative) ago")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Automation")
        }
    }
    
    private var intervalSettingsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Refresh Interval")
                        .font(.headline)
                    Spacer()
                    Text(formatInterval(configuration.globalInterval))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(
                    value: Binding(
                        get: { configuration.globalInterval },
                        set: { interval in
                            let newInterval = max(60, interval) // Minimum 1 minute
                            configuration = SmartListRefreshConfiguration(
                                isEnabled: configuration.isEnabled,
                                globalInterval: newInterval,
                                maxRefreshPerCycle: configuration.maxRefreshPerCycle,
                                refreshOnForeground: configuration.refreshOnForeground,
                                refreshOnNetworkChange: configuration.refreshOnNetworkChange
                            )
                            Task {
                                await backgroundManager.updateConfiguration(configuration)
                            }
                        }
                    ),
                    in: 60...3600, // 1 minute to 1 hour
                    step: 60
                )
                
                HStack {
                    Text("1 min")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("1 hour")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Timing")
        } footer: {
            Text("How often smart lists are checked for updates. Individual smart lists can override this setting.")
        }
        .disabled(!configuration.isEnabled)
    }
    
    private var advancedSettingsSection: some View {
        Section {
            DisclosureGroup("Advanced Settings", isExpanded: $showingAdvancedSettings) {
                VStack(spacing: 12) {
                    Toggle("Refresh on App Foreground", isOn: Binding(
                        get: { configuration.refreshOnForeground },
                        set: { enabled in
                            configuration = SmartListRefreshConfiguration(
                                isEnabled: configuration.isEnabled,
                                globalInterval: configuration.globalInterval,
                                maxRefreshPerCycle: configuration.maxRefreshPerCycle,
                                refreshOnForeground: enabled,
                                refreshOnNetworkChange: configuration.refreshOnNetworkChange
                            )
                            Task {
                                await backgroundManager.updateConfiguration(configuration)
                            }
                        }
                    ))
                    
                    Toggle("Refresh on Network Change", isOn: Binding(
                        get: { configuration.refreshOnNetworkChange },
                        set: { enabled in
                            configuration = SmartListRefreshConfiguration(
                                isEnabled: configuration.isEnabled,
                                globalInterval: configuration.globalInterval,
                                maxRefreshPerCycle: configuration.maxRefreshPerCycle,
                                refreshOnForeground: configuration.refreshOnForeground,
                                refreshOnNetworkChange: enabled
                            )
                            Task {
                                await backgroundManager.updateConfiguration(configuration)
                            }
                        }
                    ))
                    
                    HStack {
                        Text("Max Refresh Per Cycle")
                        Spacer()
                        Stepper(
                            "\(configuration.maxRefreshPerCycle)",
                            value: Binding(
                                get: { configuration.maxRefreshPerCycle },
                                set: { count in
                                    configuration = SmartListRefreshConfiguration(
                                        isEnabled: configuration.isEnabled,
                                        globalInterval: configuration.globalInterval,
                                        maxRefreshPerCycle: max(1, count),
                                        refreshOnForeground: configuration.refreshOnForeground,
                                        refreshOnNetworkChange: configuration.refreshOnNetworkChange
                                    )
                                    Task {
                                        await backgroundManager.updateConfiguration(configuration)
                                    }
                                }
                            ),
                            in: 1...50
                        )
                    }
                }
            }
        }
        .disabled(!configuration.isEnabled)
    }
    
    private var performanceSection: some View {
        Section {
            DisclosureGroup("Performance Metrics", isExpanded: $showingPerformanceMetrics) {
                PerformanceMetricsView(backgroundManager: backgroundManager)
            }
        }
    }
    
    private var actionsSection: some View {
        Section {
            Button(action: {
                Task {
                    await backgroundManager.forceRefreshAll()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh All Smart Lists Now")
                    
                    if backgroundManager.activeRefreshCount > 0 {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(!configuration.isEnabled || backgroundManager.activeRefreshCount > 0)
        } header: {
            Text("Actions")
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Performance Metrics View

private struct PerformanceMetricsView: View {
    
    @ObservedObject private var backgroundManager: DefaultSmartListBackgroundManager
    @State private var metrics: [String: TimeInterval] = [:]
    
    init(backgroundManager: DefaultSmartListBackgroundManager) {
        self.backgroundManager = backgroundManager
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if metrics.isEmpty {
                Text("No performance data available yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(metrics.keys.sorted()), id: \.self) { smartListId in
                    if let time = metrics[smartListId] {
                        HStack {
                            Text(smartListId == "all_smart_lists" ? "All Lists" : smartListId)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(String(format: "%.2fs", time))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .task {
            metrics = await backgroundManager.getPerformanceMetrics()
        }
        .refreshable {
            metrics = await backgroundManager.getPerformanceMetrics()
        }
    }
}

// MARK: - Settings Integration View

/// View for integrating background settings into the main settings screen
public struct SmartListBackgroundSettingsRow: View {
    
    @ObservedObject private var backgroundManager: DefaultSmartListBackgroundManager
    @State private var isEnabled = false
    
    public init(backgroundManager: DefaultSmartListBackgroundManager) {
        self.backgroundManager = backgroundManager
    }
    
    public var body: some View {
        NavigationLink(destination: SmartListBackgroundSettingsView(backgroundManager: backgroundManager)) {
            HStack {
                Image(systemName: "gearshape.2")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Smart List Automation")
                        .font(.body)
                    
                    Text(isEnabled ? "Background refresh enabled" : "Background refresh disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if backgroundManager.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .task {
            let config = await backgroundManager.configuration
            isEnabled = config.isEnabled
        }
    }
}
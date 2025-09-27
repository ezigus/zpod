import SwiftUI
import CoreModels

/// View for displaying batch operation options and progress
public struct BatchOperationView: View {
    let selectedEpisodes: [Episode]
    let availableOperations: [BatchOperationType]
    let onOperationSelected: (BatchOperationType) -> Void
    let onCancel: () -> Void
    
    @State private var showingPlaylistSelection = false
    @State private var selectedPlaylistID: String?
    
    public init(
        selectedEpisodes: [Episode],
        availableOperations: [BatchOperationType],
        onOperationSelected: @escaping (BatchOperationType) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.selectedEpisodes = selectedEpisodes
        self.availableOperations = availableOperations
        self.onOperationSelected = onOperationSelected
        self.onCancel = onCancel
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                operationsGrid
                Spacer()
            }
            .navigationTitle("Batch Operations")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .sheet(isPresented: $showingPlaylistSelection) {
            PlaylistSelectionView(
                onPlaylistSelected: { playlistID in
                    selectedPlaylistID = playlistID
                    onOperationSelected(.addToPlaylist)
                    showingPlaylistSelection = false
                },
                onCancel: {
                    showingPlaylistSelection = false
                }
            )
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
                
                Text("\(selectedEpisodes.count) episodes selected")
                    .font(.headline)
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
        }
        .background(Color(.systemGray6))
    }
    
    private var operationsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
            ForEach(availableOperations, id: \.self) { operation in
                BatchOperationButton(
                    operation: operation,
                    episodeCount: selectedEpisodes.count
                ) {
                    if operation == .addToPlaylist {
                        showingPlaylistSelection = true
                    } else {
                        onOperationSelected(operation)
                    }
                }
            }
        }
        .padding()
    }
}

/// Individual batch operation button
public struct BatchOperationButton: View {
    let operation: BatchOperationType
    let episodeCount: Int
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: operation.systemIcon)
                    .font(.title2)
                    .foregroundStyle(operationColor)
                
                Text(operation.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                
                Text("\(episodeCount) episodes")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(operationColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(operation.displayName)
        .accessibilityLabel(operation.displayName)
        .accessibilityHint("Performs \(operation.displayName) on \(episodeCount) episodes")
    }
    
    private var operationColor: Color {
        switch operation {
        case .delete:
            return .red
        case .markAsPlayed, .favorite, .bookmark:
            return .green
        case .download:
            return .blue
        case .archive:
            return .orange
        default:
            return .primary
        }
    }
}

/// Progress view for active batch operations with enhanced error handling
public struct BatchOperationProgressView: View {
    let batchOperation: BatchOperation
    let onCancel: () -> Void
    let onRetry: (() -> Void)?
    let onUndo: (() -> Void)?
    
    public init(
        batchOperation: BatchOperation,
        onCancel: @escaping () -> Void,
        onRetry: (() -> Void)? = nil,
        onUndo: (() -> Void)? = nil
    ) {
        self.batchOperation = batchOperation
        self.onCancel = onCancel
        self.onRetry = onRetry
        self.onUndo = onUndo
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(batchOperation.operationType.displayName)
                        .font(.headline)
                    
                    Text("\(batchOperation.completedCount) of \(batchOperation.totalCount) episodes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Action buttons based on status
                actionButtons
            }
            
            // Progress bar with enhanced visual feedback
            ProgressView(value: batchOperation.progress)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor))
                .animation(.easeInOut(duration: 0.3), value: batchOperation.progress)
            
            // Enhanced status indicator with detailed feedback
            HStack {
                statusIcon
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Failure count with retry option
                if batchOperation.failedCount > 0 {
                    HStack(spacing: 4) {
                        Text("\(batchOperation.failedCount) failed")
                            .font(.caption)
                            .foregroundStyle(.red)
                        
                        if let onRetry = onRetry, batchOperation.status != .running {
                            Button("Retry", action: onRetry)
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            
            // Success message with undo option for reversible operations
            if batchOperation.status == .completed && batchOperation.operationType.isReversible {
                HStack {
                    Text("Operation completed successfully")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    Spacer()
                    
                    if let onUndo = onUndo {
                        Button("Undo", action: onUndo)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(backgroundColorForStatus)
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColorForStatus, lineWidth: 1)
        )
        .accessibilityIdentifier("Batch Operation Progress")
        .accessibilityLabel("Batch operation progress: \(batchOperation.operationType.displayName)")
        .accessibilityValue("\(batchOperation.completedCount) of \(batchOperation.totalCount) episodes completed")
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 8) {
            if batchOperation.status == .running {
                Button("Cancel", action: onCancel)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
    
    private var statusIcon: some View {
        Group {
            switch batchOperation.status {
            case .running:
                ProgressView()
                    .scaleEffect(0.8)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.orange)
            case .pending:
                Image(systemName: "clock.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
    }
    
    private var statusText: String {
        switch batchOperation.status {
        case .running:
            return "Processing..."
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        case .pending:
            return "Pending"
        }
    }
    
    private var progressColor: Color {
        switch batchOperation.status {
        case .running:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .orange
        case .pending:
            return .gray
        }
    }
    
    private var backgroundColorForStatus: Color {
        switch batchOperation.status {
        case .running:
            return Color(.systemGray6)
        case .completed:
            return Color.green.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.1)
        case .cancelled:
            return Color.orange.opacity(0.1)
        case .pending:
            return Color.blue.opacity(0.1)
        }
    }
    
    private var borderColorForStatus: Color {
        switch batchOperation.status {
        case .running:
            return Color.clear
        case .completed:
            return Color.green.opacity(0.3)
        case .failed:
            return Color.red.opacity(0.3)
        case .cancelled:
            return Color.orange.opacity(0.3)
        case .pending:
            return Color.blue.opacity(0.3)
        }
    }
}

/// Placeholder playlist selection view
public struct PlaylistSelectionView: View {
    let onPlaylistSelected: (String) -> Void
    let onCancel: () -> Void
    
    // Mock playlists for demonstration
    private let mockPlaylists = [
        ("playlist-1", "Favorites"),
        ("playlist-2", "Later"),
        ("playlist-3", "Workout")
    ]
    
    public var body: some View {
        NavigationView {
            List(mockPlaylists, id: \.0) { playlist in
                Button(action: {
                    onPlaylistSelected(playlist.0)
                }) {
                    HStack {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(.blue)
                        Text(playlist.1)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Select Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

/// View for selecting episodes by criteria
public struct EpisodeSelectionCriteriaView: View {
    @State private var criteria = EpisodeSelectionCriteria()
    @State private var selectedPlayStatus: EpisodeSelectionCriteria.PlayStatus?
    @State private var selectedDownloadStatus: EpisodeDownloadStatus?
    @State private var olderThanDays: Int = 30
    @State private var newerThanDays: Int = 7
    @State private var useOlderThan = false
    @State private var useNewerThan = false
    
    let onApply: (EpisodeSelectionCriteria) -> Void
    let onCancel: () -> Void
    
    public init(
        onApply: @escaping (EpisodeSelectionCriteria) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onApply = onApply
        self.onCancel = onCancel
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section("Play Status") {
                    Picker("Status", selection: $selectedPlayStatus) {
                        Text("Any").tag(nil as EpisodeSelectionCriteria.PlayStatus?)
                        ForEach(EpisodeSelectionCriteria.PlayStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status as EpisodeSelectionCriteria.PlayStatus?)
                        }
                    }
                }
                
                Section("Download Status") {
                    Picker("Status", selection: $selectedDownloadStatus) {
                        Text("Any").tag(nil as EpisodeDownloadStatus?)
                        ForEach(EpisodeDownloadStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status as EpisodeDownloadStatus?)
                        }
                    }
                }
                
                Section("Date Range") {
                    Toggle("Episodes older than", isOn: $useOlderThan)
                    if useOlderThan {
                        Stepper("\(olderThanDays) days", value: $olderThanDays, in: 1...365)
                    }
                    
                    Toggle("Episodes newer than", isOn: $useNewerThan)
                    if useNewerThan {
                        Stepper("\(newerThanDays) days", value: $newerThanDays, in: 1...365)
                    }
                }
                
                Section("Other Filters") {
                    Toggle("Favorites only", isOn: Binding(
                        get: { criteria.favoriteStatus == true },
                        set: { criteria.favoriteStatus = $0 ? true : nil }
                    ))
                    
                    Toggle("Bookmarked only", isOn: Binding(
                        get: { criteria.bookmarkStatus == true },
                        set: { criteria.bookmarkStatus = $0 ? true : nil }
                    ))
                    
                    Toggle("Archived only", isOn: Binding(
                        get: { criteria.archiveStatus == true },
                        set: { criteria.archiveStatus = $0 ? true : nil }
                    ))
                }
            }
            .navigationTitle("Select Episodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        buildCriteriaAndApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func buildCriteriaAndApply() {
        var finalCriteria = EpisodeSelectionCriteria()
        finalCriteria.playStatus = selectedPlayStatus
        finalCriteria.downloadStatus = selectedDownloadStatus
        finalCriteria.olderThanDays = useOlderThan ? olderThanDays : nil
        finalCriteria.newerThanDays = useNewerThan ? newerThanDays : nil
        finalCriteria.favoriteStatus = criteria.favoriteStatus
        finalCriteria.bookmarkStatus = criteria.bookmarkStatus
        finalCriteria.archiveStatus = criteria.archiveStatus
        
        onApply(finalCriteria)
    }
}

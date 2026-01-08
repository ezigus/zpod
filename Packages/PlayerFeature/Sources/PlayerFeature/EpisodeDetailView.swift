#if os(iOS) || os(macOS)
import Foundation
import SwiftUI
import CoreModels
import PlaybackEngine
import SharedUtilities
/// Episode Detail view showing episode information and playback controls
public struct EpisodeDetailView: View {
  @StateObject private var viewModel: EpisodeDetailViewModel
  let episode: Episode
  @State private var noteDraftText = ""
  @State private var noteDraftTags = ""
  @State private var includeCurrentTimestamp = false
  @State private var editingNote: EpisodeNote?
  @State private var bookmarkLabel = ""
  @State private var useCurrentTimestampForBookmark = true
  @State private var customBookmarkTimestamp = ""
  @State private var bookmarkValidationMessage: String?
  @State private var transcriptSearchText = ""
  @State private var showingSpeedOptions = false

  public init(episode: Episode, playbackService: EpisodePlaybackService? = nil) {
    self.episode = episode
    self._viewModel = StateObject(
      wrappedValue: EpisodeDetailViewModel(playbackService: playbackService))
  }

  public var body: some View {
    ZStack(alignment: .topTrailing) {
      ScrollView {
        content
          .accessibilityElement(children: .contain)
          .accessibilityIdentifier("Episode Detail View")
      }

      if isPlaybackDebugEnabled {
        VStack {
          Spacer()
            .frame(height: 8)  // Small gap below nav bar
          HStack {
            Spacer()
            PlaybackDebugControlsView()
              .padding(.trailing, 12)
          }
          Spacer()
        }
        .allowsHitTesting(true)
      }
    }
    .navigationTitle("Episode")
#if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
#endif
    .onAppear {
      viewModel.loadEpisode(episode)
      bookmarkLabel = defaultBookmarkLabel()
      transcriptSearchText = viewModel.transcriptSearchQuery
    }
    .onChange(of: viewModel.transcriptSearchQuery) { _, newValue in
      if transcriptSearchText != newValue {
        transcriptSearchText = newValue
      }
    }
  }

}

extension EpisodeDetailView {

  @ViewBuilder
  private var content: some View {
    VStack(alignment: .leading, spacing: 20) {
      Color.clear
        .frame(height: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("Player Interface")
        .accessibilityLabel("Player Interface")
      artworkView
      headerSection
      playbackControlsSection
      chaptersSection
      metadataSection
      ratingSection
      bookmarksSection
      notesSection
      transcriptSection
      Spacer()
    }
    .padding()
  }

  private func formatChapterTime(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
  }

  private var isPlaybackDebugEnabled: Bool {
    ProcessInfo.processInfo.environment["UITEST_PLAYBACK_DEBUG"] == "1"
  }

  private struct PlaybackDebugControlsView: View {
    var body: some View {
      VStack(alignment: .trailing, spacing: 8) {
        Button("Interruption Began") {
          postInterruption(.began, shouldResume: false)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("Playback.Debug.InterruptionBegan")

        Button("Interruption Ended") {
          postInterruption(.ended, shouldResume: true)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("Playback.Debug.InterruptionEnded")
      }
      .padding(8)
      .background(Color.black.opacity(0.6))
      .cornerRadius(8)
      .accessibilityIdentifier("Playback Debug Controls")
      .zIndex(1000)  // Ensure overlay stays on top
    }

    private func postInterruption(
      _ type: PlaybackDebugInterruptionType,
      shouldResume: Bool
    ) {
      NotificationCenter.default.post(
        name: .playbackDebugInterruption,
        object: nil,
        userInfo: [
          PlaybackDebugNotificationKey.interruptionType: type.rawValue,
          PlaybackDebugNotificationKey.shouldResume: shouldResume
        ]
      )
    }
  }

  private var artworkView: some View {
    Group {
      if let url = episode.artworkURL {
        AsyncImage(url: url) { phase in
          switch phase {
          case .empty:
            placeholderArtwork
          case .success(let image):
            image.resizable().scaledToFit()
          case .failure:
            placeholderArtwork
          @unknown default:
            placeholderArtwork
          }
        }
      } else {
        placeholderArtwork
      }
    }
    .frame(width: 120, height: 120)
    .foregroundColor(.secondary)
    .accessibilityIdentifier("Episode Artwork")
    .accessibilityLabel("Episode Artwork")
  }

  private var placeholderArtwork: some View {
    Image(systemName: "music.note")
      .resizable()
      .scaledToFit()
  }

  private var progressAccessibilitySlider: some View {
    let upperBound = max(viewModel.duration, viewModel.currentPosition, 1)
    return Slider(
      value: Binding(
        get: { viewModel.currentPosition },
        set: { newValue in viewModel.seek(to: newValue) }
      ),
      in: 0...upperBound
    )
    .labelsHidden()
    .opacity(0.01)
    .accessibilityIdentifier("Progress Slider")
    .accessibilityLabel("Progress Slider")
    .accessibilityHint("Adjust playback position")
    .accessibilityValue(Text("\(viewModel.formattedCurrentTime) of \(viewModel.formattedDuration)"))
    .disabled(viewModel.episode == nil || upperBound <= 0)
  }

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(episode.title)
        .font(.title2)
        .fontWeight(.bold)
        .multilineTextAlignment(.leading)
        .accessibilityIdentifier("Episode Title")

      if let description = episode.description {
        Text(description)
          .font(.body)
          .foregroundColor(.secondary)
      }
    }
  }

  private var playbackControlsSection: some View {
    VStack(spacing: 16) {
      progressSection
      playbackButtonsRow
      playbackSpeedRow
    }
    .padding()
    .background(Color.platformSystemGray6)
    .cornerRadius(12)
  }

  private var progressSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      ProgressView(value: viewModel.progressFraction)
        .progressViewStyle(LinearProgressViewStyle())

      HStack {
        Text(viewModel.formattedCurrentTime)
          .font(.caption)
          .foregroundColor(.secondary)

        Spacer()

        Text(viewModel.formattedDuration)
          .font(.caption)
          .foregroundColor(.secondary)
      }

      progressAccessibilitySlider
    }
  }

  private var playbackButtonsRow: some View {
    HStack(spacing: 20) {
      Button(action: {
        viewModel.skipBackward()
      }) {
        Image(systemName: "gobackward.15")
          .font(.title2)
          .foregroundColor(.accentColor)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityIdentifier("Skip Backward")
      .accessibilityLabel("Skip Backward")
      .disabled(viewModel.episode == nil)

      Spacer()

      Button(action: {
        viewModel.playPause()
      }) {
        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .font(.largeTitle)
          .foregroundColor(.accentColor)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityIdentifier(viewModel.isPlaying ? "Pause" : "Play")
      .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
      .disabled(viewModel.episode == nil)

      Spacer()

      Button(action: {
        viewModel.skipForward()
      }) {
        Image(systemName: "goforward.30")
          .font(.title2)
          .foregroundColor(.accentColor)
          .frame(minWidth: 44, minHeight: 44)
          .contentShape(Rectangle())
      }
      .accessibilityIdentifier("Skip Forward")
      .accessibilityLabel("Skip Forward")
      .disabled(viewModel.episode == nil)
    }
  }

  private var playbackSpeedRow: some View {
    HStack {
      Text("Speed:")
        .font(.caption)
        .foregroundColor(.secondary)

      Spacer()

      Button(action: {
        showingSpeedOptions = true
      }) {
        Text("\(Double(viewModel.playbackSpeed), specifier: "%.2g")x")
          .font(.caption)
          .foregroundColor(.accentColor)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.platformSystemGray5)
          .cornerRadius(8)
      }
      .accessibilityIdentifier("Speed Control")
      .accessibilityLabel(String(format: "Speed %.1fx", Double(viewModel.playbackSpeed)))
      .accessibilityHint("Adjust playback speed")
      .confirmationDialog("Playback Speed", isPresented: $showingSpeedOptions) {
        ForEach([Float(1.0), 1.5, 2.0], id: \.self) { speed in
          let label = String(format: "%.1fx", Double(speed))
          Button(label) {
            viewModel.setPlaybackSpeed(speed)
            showingSpeedOptions = false
          }
          .accessibilityIdentifier("PlaybackSpeed.Option.\(label)")
        }
        Button("Cancel", role: .cancel) {
          showingSpeedOptions = false
        }
      }
    }
  }

  @ViewBuilder
  private var chaptersSection: some View {
    if !viewModel.chapters.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Text("Chapters")
          .font(.headline)
          .fontWeight(.semibold)

        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(viewModel.chapters, id: \.id) { chapter in
            Button(action: {
              viewModel.jumpToChapter(chapter)
            }) {
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(chapter.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)

                  Text(formatChapterTime(chapter.startTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                if viewModel.currentChapter?.id == chapter.id {
                  Image(systemName: "play.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.caption)
                }
              }
              .padding(.vertical, 8)
              .padding(.horizontal, 12)
              .background(
                viewModel.currentChapter?.id == chapter.id ? Color.platformSystemGray5 : Color.clear
              )
              .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
          }
        }
      }
      .padding()
      .background(Color.platformSystemGray6)
      .cornerRadius(12)
    }
  }

  private var ratingSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Your Rating")
        .font(.headline)
        .fontWeight(.semibold)

      HStack(spacing: 8) {
        ForEach(1...5, id: \.self) { star in
          Button(action: {
            viewModel.setRating(viewModel.userRating == star ? nil : star)
          }) {
            Image(systemName: viewModel.userRating ?? 0 >= star ? "star.fill" : "star")
              .font(.title3)
              .foregroundColor(.yellow)
          }
        }

        if let rating = viewModel.userRating {
          Text("(\(rating)/5)")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.leading, 4)
        }
      }

      if let community = viewModel.metadata?.formattedCommunityRating {
        Text("Community: \(community)")
          .font(.caption)
          .foregroundColor(.secondary)
          .accessibilityLabel("Community rating \(community)")
      } else {
        Text("Community rating coming soon")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .padding()
    .background(Color.platformSystemGray6)
    .cornerRadius(12)
  }

  private var bookmarksSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Bookmarks")
        .font(.headline)
        .fontWeight(.semibold)

      bookmarkComposer

      if viewModel.bookmarks.isEmpty {
        Text("No bookmarks yet. Add one to jump back to important moments.")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.vertical, 8)
      } else {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(viewModel.bookmarks) { bookmark in
            HStack {
              Button(action: {
                viewModel.jumpToBookmark(bookmark)
              }) {
                VStack(alignment: .leading, spacing: 2) {
                  Text(bookmark.displayLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)

                  Text(bookmark.formattedTimestamp)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
              .buttonStyle(PlainButtonStyle())

              Spacer()

              Button(action: {
                viewModel.deleteBookmark(bookmark)
              }) {
                Image(systemName: "trash")
                  .font(.caption)
                  .foregroundColor(.red)
              }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.platformSystemGray5)
            .cornerRadius(8)
          }
        }
      }
    }
    .padding()
    .background(Color.platformSystemGray6)
    .cornerRadius(12)
  }

  private var notesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Notes")
        .font(.headline)
        .fontWeight(.semibold)

      noteComposer

      if viewModel.notes.isEmpty {
        Text("No notes yet. Capture your thoughts with the composer above.")
          .font(.caption)
          .foregroundColor(.secondary)
          .padding(.vertical, 8)
      } else {
        LazyVStack(alignment: .leading, spacing: 8) {
          ForEach(viewModel.notes) { note in
            VStack(alignment: .leading, spacing: 6) {
              Text(note.text)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
                .fontWeight(editingNote?.id == note.id ? .semibold : .regular)

              if note.hasTags {
                HStack(spacing: 4) {
                  ForEach(note.tags, id: \.self) { tag in
                    Text("#\(tag)")
                      .font(.caption2)
                      .padding(.horizontal, 6)
                      .padding(.vertical, 2)
                      .background(Color.accentColor.opacity(0.2))
                      .cornerRadius(4)
                  }
                }
              }

              HStack {
                if let timestamp = note.formattedTimestamp {
                  Text("at \(timestamp)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button("Edit") {
                  beginEditing(note)
                }
                .font(.caption2)

                Button(action: {
                  viewModel.deleteNote(note)
                  if editingNote?.id == note.id {
                    resetNoteComposer()
                  }
                }) {
                  Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundColor(.red)
                }
              }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
              editingNote?.id == note.id ? Color.accentColor.opacity(0.1) : Color.platformSystemGray5
            )
            .cornerRadius(8)
          }
        }
      }
    }
    .padding()
    .background(Color.platformSystemGray6)
    .cornerRadius(12)
  }

  private func transcriptRow(for segment: TranscriptSegment, highlightQuery: String) -> some View {
    Button(action: {
      viewModel.jumpToTranscriptSegment(segment)
    }) {
      HStack(alignment: .top, spacing: 8) {
        Text(formatChapterTime(segment.startTime))
          .font(.caption)
          .foregroundColor(.secondary)
          .frame(width: 50, alignment: .leading)

        highlightedTranscriptText(segment.text, query: highlightQuery)
          .font(.subheadline)
          .foregroundColor(.primary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 10)
      .background(
        viewModel.transcript?.segment(at: viewModel.currentPosition)?.id == segment.id
          ? Color.accentColor.opacity(0.2)
          : Color.platformSystemGray5
      )
      .cornerRadius(6)
    }
    .buttonStyle(PlainButtonStyle())
  }

  private var bookmarkComposer: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField("Bookmark label", text: $bookmarkLabel)
        .textFieldStyle(RoundedBorderTextFieldStyle())

      Toggle(
        "Use current playback time (\(viewModel.formattedCurrentTime))",
        isOn: $useCurrentTimestampForBookmark
      )
      .onChange(of: useCurrentTimestampForBookmark) { _, isUsingCurrent in
        if isUsingCurrent {
          customBookmarkTimestamp = ""
        }
      }

      if !useCurrentTimestampForBookmark {
        TextField("Custom timestamp (hh:mm:ss or mm:ss)", text: $customBookmarkTimestamp)
          .textFieldStyle(RoundedBorderTextFieldStyle())
#if os(iOS)
          .keyboardType(.numbersAndPunctuation)
          .textInputAutocapitalization(.never)
#endif
      }

      if let message = bookmarkValidationMessage {
        Text(message)
          .font(.caption)
          .foregroundColor(.red)
      }

      HStack {
        Button(action: saveBookmark) {
          Label("Save Bookmark", systemImage: "bookmark.fill")
        }
        .disabled(viewModel.episode == nil)

        Button("Reset", action: resetBookmarkComposer)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .accessibilityElement(children: .contain)
  }

  private var noteComposer: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextEditor(text: $noteDraftText)
        .frame(minHeight: 80)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color.platformSystemGray4)
        )
        .accessibilityLabel(editingNote != nil ? "Edit note" : "New note")

      TextField("Tags (comma separated)", text: $noteDraftTags)
        .textFieldStyle(RoundedBorderTextFieldStyle())

      Toggle(
        "Attach current timestamp (\(viewModel.formattedCurrentTime))",
        isOn: $includeCurrentTimestamp
      )
      .disabled(editingNote != nil)

      HStack {
        Button(action: saveCurrentNote) {
          Label(editingNote == nil ? "Save Note" : "Update Note", systemImage: "square.and.pencil")
        }
        .disabled(noteDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        if editingNote != nil {
          Button("Cancel", action: resetNoteComposer)
            .font(.caption)
            .foregroundColor(.secondary)
        } else if !noteDraftText.isEmpty || !noteDraftTags.isEmpty {
          Button("Clear", action: resetNoteComposer)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func highlightedTranscriptText(_ text: String, query: String) -> Text {
    guard !query.isEmpty else { return Text(text) }

    var segments: [Text] = []
    var searchStart = text.startIndex

    while searchStart < text.endIndex,
      let range = text.range(
        of: query,
        options: [.caseInsensitive, .diacriticInsensitive],
        range: searchStart..<text.endIndex,
        locale: .current
      )
    {
      if range.lowerBound > searchStart {
        let prefix = text[searchStart..<range.lowerBound]
        segments.append(Text(String(prefix)))
      }

      let match = text[range]
      segments.append(Text(String(match)).bold().foregroundStyle(Color.accentColor))

      searchStart = range.upperBound
    }

    if searchStart < text.endIndex {
      let suffix = text[searchStart..<text.endIndex]
      segments.append(Text(String(suffix)))
    }

    return segments.reduce(Text("")) { $0 + $1 }
  }

  private func saveBookmark() {
    bookmarkValidationMessage = nil

    let trimmedLabel = bookmarkLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    let finalLabel = trimmedLabel.isEmpty ? defaultBookmarkLabel() : trimmedLabel

    let timestamp: TimeInterval
    if useCurrentTimestampForBookmark {
      timestamp = viewModel.currentPosition
    } else {
      guard let parsed = parseTimestampInput(customBookmarkTimestamp) else {
        bookmarkValidationMessage = "Enter time as hh:mm:ss, mm:ss, or seconds."
        return
      }
      timestamp = parsed
    }

    viewModel.createBookmark(at: timestamp, label: finalLabel)
    resetBookmarkComposer()
  }

  private func resetBookmarkComposer() {
    bookmarkLabel = defaultBookmarkLabel()
    useCurrentTimestampForBookmark = true
    customBookmarkTimestamp = ""
    bookmarkValidationMessage = nil
  }

  private func defaultBookmarkLabel() -> String {
    "Bookmark at \(viewModel.formattedCurrentTime)"
  }

  private func parseTimestampInput(_ input: String) -> TimeInterval? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let components = trimmed.split(separator: ":")
    switch components.count {
    case 1:
      return TimeInterval(components[0])
    case 2:
      guard let minutes = Double(components[0]),
            let seconds = Double(components[1]) else { return nil }
      return minutes * 60 + seconds
    case 3:
      guard let hours = Double(components[0]),
            let minutes = Double(components[1]),
            let seconds = Double(components[2]) else { return nil }
      return hours * 3600 + minutes * 60 + seconds
    default:
      return nil
    }
  }

  private func saveCurrentNote() {
    let trimmedText = noteDraftText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedText.isEmpty else { return }

    let tags = parseTags(noteDraftTags)

    if let editingNote {
      let noteToUpdate = editingNote
      Task {
        try? await viewModel.updateNote(
          noteToUpdate,
          newText: trimmedText,
          newTags: tags
        )
        resetNoteComposer()
      }
    } else {
      let timestamp = includeCurrentTimestamp ? viewModel.currentPosition : nil
      Task {
        try? await viewModel.createNote(
          text: trimmedText,
          tags: tags,
          timestamp: timestamp
        )
        resetNoteComposer()
      }
    }
  }

  private func resetNoteComposer() {
    editingNote = nil
    noteDraftText = ""
    noteDraftTags = ""
    includeCurrentTimestamp = false
  }

  private func beginEditing(_ note: EpisodeNote) {
    editingNote = note
    noteDraftText = note.text
    noteDraftTags = note.tags.joined(separator: ", ")
    includeCurrentTimestamp = note.timestamp != nil
  }

  private func parseTags(_ input: String) -> [String] {
    input
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  @ViewBuilder
  private var transcriptSection: some View {
    if let transcript = viewModel.transcript {
      VStack(alignment: .leading, spacing: 12) {
        Text("Transcript")
          .font(.headline)
          .fontWeight(.semibold)

        TextField("Search transcript", text: $transcriptSearchText)
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .accessibilityLabel("Search transcript")
          .onChange(of: transcriptSearchText) { _, newValue in
            viewModel.updateTranscriptSearch(query: newValue)
          }

        if !viewModel.transcriptSearchQuery.isEmpty {
          if viewModel.transcriptSearchResults.isEmpty {
            Text("No transcript matches for \"\(viewModel.transcriptSearchQuery)\".")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            LazyVStack(alignment: .leading, spacing: 8) {
              ForEach(viewModel.transcriptSearchResults) { result in
                transcriptRow(for: result.segment, highlightQuery: viewModel.transcriptSearchQuery)
              }
            }
          }
        } else {
          LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(transcript.segments) { segment in
              transcriptRow(for: segment, highlightQuery: "")
            }
          }
        }
      }
      .padding()
      .background(Color.platformSystemGray6)
      .cornerRadius(12)
    }
  }

  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Episode Information")
        .font(.headline)
        .fontWeight(.semibold)

      VStack(spacing: 8) {
        if !episode.podcastTitle.isEmpty {
          MetadataRow(
            label: "Podcast",
            value: episode.podcastTitle,
            valueIdentifier: "Podcast Title"
          )
        }

        if let pubDate = episode.pubDate {
          MetadataRow(label: "Published", value: formattedDate(pubDate))
        }

        if let duration = episode.duration {
          MetadataRow(label: "Duration", value: formatDuration(duration))
        }

        if let fileSize = viewModel.metadata?.formattedFileSize {
          MetadataRow(label: "File Size", value: fileSize)
        }

        if let bitrate = viewModel.metadata?.formattedBitrate {
          MetadataRow(label: "Bitrate", value: bitrate)
        }

        if let format = viewModel.metadata?.format {
          MetadataRow(label: "Format", value: format.uppercased())
        }

        if let sampleRate = viewModel.metadata?.formattedSampleRate {
          MetadataRow(label: "Sample Rate", value: sampleRate)
        }

        if let channels = viewModel.metadata?.channelDescription {
          MetadataRow(label: "Audio", value: channels)
        }

        if viewModel.metadata == nil,
           episode.podcastTitle.isEmpty,
           episode.pubDate == nil,
           episode.duration == nil {
          Text("Metadata not available")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding()
    .background(Color.platformSystemGray6)
    .cornerRadius(12)
  }

  private func formattedDate(_ date: Date) -> String {
    Self.dateFormatter.string(from: date)
  }

  private func formatDuration(_ seconds: TimeInterval) -> String {
    if seconds >= 3600 {
      let hours = Int(seconds) / 3600
      let minutes = (Int(seconds) % 3600) / 60
      let secs = Int(seconds) % 60
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return formatChapterTime(seconds)
  }

  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()
}

// MARK: - Helper Views

private struct MetadataRow: View {
  let label: String
  let value: String
  var valueIdentifier: String? = nil
  
  var body: some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundColor(.secondary)
      Spacer()
      if let valueIdentifier {
        Text(value)
          .font(.subheadline)
          .fontWeight(.medium)
          .accessibilityIdentifier(valueIdentifier)
      } else {
        Text(value)
          .font(.subheadline)
          .fontWeight(.medium)
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }
}

#else
import SwiftUI
import CoreModels
import PlaybackEngine

public struct EpisodeDetailView: View {
  public init(episode: Episode, playbackService: EpisodePlaybackService? = nil) {}

  public var body: some View {
    Text("Episode detail view is available on iOS only.")
  }
}
#endif

// MARK: - Previews
#Preview("Episode with Description") {
  NavigationView {
    EpisodeDetailView(
      episode: Episode(
        id: "episode-1",
        title: "Introduction to Podcast Development",
        pubDate: nil,
        duration: 1800,  // 30 minutes
        description:
          "In this episode, we explore the fundamentals of building a podcast application using SwiftUI and modern iOS development practices. " +
          "We'll cover architecture patterns, data management, and user interface design.",
        audioURL: URL(string: "https://example.com/episode1.mp3")
      ))
  }
}

#Preview("Episode without Description") {
  NavigationView {
    EpisodeDetailView(
      episode: Episode(
        id: "episode-2",
        title: "Advanced SwiftUI Techniques",
        pubDate: nil,
        duration: 2400,  // 40 minutes
        description: nil,
        audioURL: URL(string: "https://example.com/episode2.mp3")
      ))
  }
}

#if os(iOS) || os(macOS)
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

  public init(episode: Episode, playbackService: EpisodePlaybackService? = nil) {
    self.episode = episode
    self._viewModel = StateObject(
      wrappedValue: EpisodeDetailViewModel(playbackService: playbackService))
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        // Episode title
        Text(episode.title)
          .font(.title2)
          .fontWeight(.bold)
          .multilineTextAlignment(.leading)

        // Episode description (if available)
        if let description = episode.description {
          Text(description)
            .font(.body)
            .foregroundColor(.secondary)
        }

        // Playback controls section
        VStack(spacing: 16) {
          // Progress bar
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
          }

          // Control buttons row
          HStack(spacing: 20) {
            // Skip backward button
            Button(action: {
              viewModel.skipBackward()
            }) {
              Image(systemName: "gobackward.15")
                .font(.title2)
                .foregroundColor(.accentColor)
            }
            .disabled(viewModel.episode == nil)

            Spacer()

            // Play/Pause button
            Button(action: {
              viewModel.playPause()
            }) {
              Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
            }
            .disabled(viewModel.episode == nil)

            Spacer()

            // Skip forward button
            Button(action: {
              viewModel.skipForward()
            }) {
              Image(systemName: "goforward.30")
                .font(.title2)
                .foregroundColor(.accentColor)
            }
            .disabled(viewModel.episode == nil)
          }

          // Playback speed control
          HStack {
            Text("Speed:")
              .font(.caption)
              .foregroundColor(.secondary)

            Spacer()

            Button(action: {
              let speeds: [Float] = [0.8, 1.0, 1.25, 1.5, 2.0]
              let currentIndex = speeds.firstIndex(of: viewModel.playbackSpeed) ?? 1
              let nextIndex = (currentIndex + 1) % speeds.count
              viewModel.setPlaybackSpeed(speeds[nextIndex])
            }) {
              Text("\(viewModel.playbackSpeed, specifier: "%.2g")x")
                .font(.caption)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.platformSystemGray5)
                .cornerRadius(8)
            }
          }
        }
        .padding()
        .background(Color.platformSystemGray6)
        .cornerRadius(12)

        // Chapters section
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
        
        metadataSection
        
        // Rating section
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
        
        // Bookmarks section
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
        
        // Notes section
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
        
        // Transcript section
        if viewModel.transcript != nil {
          transcriptSection
        }

        Spacer()
      }
      .padding()
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

  private func formatChapterTime(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
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
          MetadataRow(label: "Podcast", value: episode.podcastTitle)
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
  
  var body: some View {
    HStack {
      Text(label)
        .font(.subheadline)
        .foregroundColor(.secondary)
      Spacer()
      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
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

#if os(iOS)
import SwiftUI
import CoreModels
import PlaybackEngine

/// Episode Detail view showing episode information and playback controls
public struct EpisodeDetailView: View {
  @StateObject private var viewModel: EpisodeDetailViewModel
  let episode: Episode

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
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }
          }
        }
        .padding()
        .background(Color(.systemGray6))
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
                    viewModel.currentChapter?.id == chapter.id ? Color(.systemGray5) : Color.clear
                  )
                  .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
              }
            }
          }
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(12)
        }
        
        // Metadata section
        if let metadata = viewModel.metadata {
          VStack(alignment: .leading, spacing: 12) {
            Text("Episode Information")
              .font(.headline)
              .fontWeight(.semibold)
            
            VStack(spacing: 8) {
              if let fileSize = metadata.formattedFileSize {
                MetadataRow(label: "File Size", value: fileSize)
              }
              if let bitrate = metadata.formattedBitrate {
                MetadataRow(label: "Bitrate", value: bitrate)
              }
              if let format = metadata.format {
                MetadataRow(label: "Format", value: format.uppercased())
              }
              if let sampleRate = metadata.formattedSampleRate {
                MetadataRow(label: "Sample Rate", value: sampleRate)
              }
              if let channels = metadata.channelDescription {
                MetadataRow(label: "Audio", value: channels)
              }
            }
          }
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(12)
        }
        
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
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        // Bookmarks section
        VStack(alignment: .leading, spacing: 12) {
          HStack {
            Text("Bookmarks")
              .font(.headline)
              .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: {
              // Use timestamp in milliseconds for unique label
              let timestampMs = Int(viewModel.currentPosition * 1000)
              viewModel.addBookmarkAtCurrentPosition(label: "Bookmark at \(viewModel.formattedCurrentTime) (\(timestampMs)ms)")
            }) {
              Label("Add", systemImage: "plus.circle.fill")
                .font(.subheadline)
            }
            .disabled(viewModel.episode == nil)
          }
          
          if viewModel.bookmarks.isEmpty {
            Text("No bookmarks yet. Add one during playback!")
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
                .background(Color(.systemGray5))
                .cornerRadius(8)
              }
            }
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        // Notes section
        VStack(alignment: .leading, spacing: 12) {
          Text("Notes")
            .font(.headline)
            .fontWeight(.semibold)
          
          if viewModel.notes.isEmpty {
            Text("No notes yet. Tap to add your first note!")
              .font(.caption)
              .foregroundColor(.secondary)
              .padding(.vertical, 8)
          } else {
            LazyVStack(alignment: .leading, spacing: 8) {
              ForEach(viewModel.notes) { note in
                VStack(alignment: .leading, spacing: 4) {
                  Text(note.text)
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                  
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
                    
                    Button(action: {
                      viewModel.deleteNote(note)
                    }) {
                      Image(systemName: "trash")
                        .font(.caption2)
                        .foregroundColor(.red)
                    }
                  }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray5))
                .cornerRadius(8)
              }
            }
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        
        // Transcript section
        if let transcript = viewModel.transcript {
          VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
              .font(.headline)
              .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
              ForEach(transcript.segments) { segment in
                Button(action: {
                  viewModel.jumpToTranscriptSegment(segment)
                }) {
                  HStack(alignment: .top, spacing: 8) {
                    Text(formatChapterTime(segment.startTime))
                      .font(.caption)
                      .foregroundColor(.secondary)
                      .frame(width: 50, alignment: .leading)
                    
                    Text(segment.text)
                      .font(.subheadline)
                      .foregroundColor(.primary)
                      .multilineTextAlignment(.leading)
                      .frame(maxWidth: .infinity, alignment: .leading)
                  }
                  .padding(.vertical, 6)
                  .padding(.horizontal, 10)
                  .background(
                    // Highlight current segment
                    viewModel.transcript?.segment(at: viewModel.currentPosition)?.id == segment.id
                      ? Color.accentColor.opacity(0.2)
                      : Color(.systemGray5)
                  )
                  .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
              }
            }
          }
          .padding()
          .background(Color(.systemGray6))
          .cornerRadius(12)
        }

        Spacer()
      }
      .padding()
    }
    .navigationTitle("Episode")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      viewModel.loadEpisode(episode)
    }
  }

  private func formatChapterTime(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    let remainingSeconds = Int(seconds) % 60
    return String(format: "%d:%02d", minutes, remainingSeconds)
  }
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

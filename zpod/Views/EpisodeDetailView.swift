import SwiftUI

/// Episode Detail view showing episode information and playback controls
struct EpisodeDetailView: View {
  @StateObject private var viewModel: EpisodeDetailViewModel
  let episode: Episode

  init(episode: Episode, playbackService: EpisodePlaybackService? = nil) {
    self.episode = episode
    self._viewModel = StateObject(
      wrappedValue: EpisodeDetailViewModel(playbackService: playbackService))
  }

  var body: some View {
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

// MARK: - Previews
#Preview("Episode with Description") {
  NavigationView {
    EpisodeDetailView(
      episode: Episode(
        id: "episode-1",
        title: "Introduction to Podcast Development",
        duration: 1800,  // 30 minutes
        description:
          "In this episode, we explore the fundamentals of building a podcast application using SwiftUI and modern iOS development practices. We'll cover architecture patterns, data management, and user interface design.",
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
        duration: 2400,  // 40 minutes
        description: nil,
        audioURL: URL(string: "https://example.com/episode2.mp3")
      ))
  }
}

import Combine
import CoreModels

/// Abstraction for streaming download progress updates from the networking layer.
@MainActor
public protocol DownloadProgressProviding {
    var progressPublisher: AnyPublisher<EpisodeDownloadProgressUpdate, Never> { get }
}

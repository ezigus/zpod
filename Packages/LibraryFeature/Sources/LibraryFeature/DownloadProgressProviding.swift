import Combine
import CoreModels

/// Abstraction for streaming download progress updates from the networking layer.
public protocol DownloadProgressProviding: Sendable {
    var progressPublisher: AnyPublisher<EpisodeDownloadProgressUpdate, Never> { get }
}

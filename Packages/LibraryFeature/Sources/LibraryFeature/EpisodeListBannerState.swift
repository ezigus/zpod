import Foundation

/// Lightweight state container representing a transient banner on the episode list.
public struct EpisodeListBannerState {
    public enum Style {
        case success
        case warning
        case failure
    }
    
    public let title: String
    public let subtitle: String
    public let style: Style
    public let retry: (() -> Void)?
    public let undo: (() -> Void)?
    
    public init(
        title: String,
        subtitle: String,
        style: Style,
        retry: (() -> Void)? = nil,
        undo: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.style = style
        self.retry = retry
        self.undo = undo
    }
}

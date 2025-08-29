import SwiftUI

/// Placeholder discovery view.
/// Real implementation deferred until DiscoverViewModel contract & tests are defined.
public struct DiscoverView: View {
  public init() {}
  
  public var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Text("Discover")
          .font(.largeTitle).bold()
          .accessibilityAddTraits(.isHeader)
        Text("Discovery feed coming soon.")
          .foregroundStyle(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding()
      .navigationTitle("Discover")
    }
  }
}

#if DEBUG
  public struct DiscoverView_Previews: PreviewProvider {
    public static var previews: some View {
      DiscoverView()
    }
  }
#endif
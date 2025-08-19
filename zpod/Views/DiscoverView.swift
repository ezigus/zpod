import SwiftUI

/// Placeholder discovery view.
/// Real implementation deferred until DiscoverViewModel contract & tests are defined.
struct DiscoverView: View {
  var body: some View {
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
  struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
      DiscoverView()
    }
  }
#endif

// filepath: /Users/ericziegler/code/zpod/zpod/ContentViewBridge.swift
// Conditional bridge for ContentView so the App can compile whether or not
// the LibraryFeature package is linked to the app target in Xcode.
// If LibraryFeature is available, we re-export its ContentView; otherwise,
// we supply a minimal placeholder to keep the app buildable.

#if canImport(LibraryFeature)
import LibraryFeature
public typealias ContentView = LibraryFeature.ContentView
#elseif canImport(SwiftUI)
import SwiftUI

public struct ContentView: View {
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            Text("LibraryFeature not linked")
                .font(.headline)
            Text("Add the LibraryFeature package to the zpod app target in Xcode → Package Dependencies and link its product, or keep this bridge.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }
}
#else
public struct ContentView { public init() {} }
#endif

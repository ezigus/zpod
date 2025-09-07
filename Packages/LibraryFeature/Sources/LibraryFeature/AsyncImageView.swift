//
//  AsyncImageView.swift
//  LibraryFeature
//
//  Created for Issue 02.1.1: Progressive image loading support
//

import SwiftUI

/// A view that asynchronously loads and displays an image with placeholder and caching
public struct AsyncImageView: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    
    public init(url: URL?, width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 8) {
        self.url = url
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
    
    public var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderView
                }
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                placeholderView
            }
        }
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.secondary.opacity(0.2))
            .frame(width: width, height: height)
            .overlay {
                Image(systemName: "waveform")
                    .foregroundStyle(.secondary)
                    .font(.system(size: min(width, height) * 0.3))
            }
            .redacted(reason: .placeholder)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 20) {
        AsyncImageView(
            url: URL(string: "https://example.com/artwork.jpg"),
            width: 60,
            height: 60
        )
        
        AsyncImageView(
            url: nil,
            width: 120,
            height: 120,
            cornerRadius: 12
        )
    }
    .padding()
}
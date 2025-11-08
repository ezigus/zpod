//
//  PlaybackAlertToastView.swift
//  PlayerFeature
//

import SharedUtilities
import SwiftUI

struct PlaybackAlertToastView: View {
  let alert: PlaybackAlertState
  let onPrimary: (() -> Void)?
  let onSecondary: (() -> Void)?
  let onDismiss: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(alert.descriptor.title)
            .font(.headline)
          Text(alert.descriptor.message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Button {
          onDismiss()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Dismiss playback alert")
      }

      HStack(spacing: 12) {
        if let secondary = alert.secondaryAction {
          Button(secondary.title) {
            onSecondary?()
          }
          .buttonStyle(SecondaryActionStyle())
        }

        if let primary = alert.primaryAction {
          Button(primary.title) {
            onPrimary?()
          }
          .buttonStyle(PrimaryActionStyle(style: alert.descriptor.style))
        }
      }
    }
    .padding()
    .background(backgroundColor(for: alert.descriptor.style).opacity(0.9))
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    .shadow(radius: 8, y: 4)
    .accessibilityElement(children: .contain)
    .accessibilityLabel("\(alert.descriptor.title). \(alert.descriptor.message)")
  }

  private func backgroundColor(for style: PlaybackAlertStyle) -> Color {
    switch style {
    case .info:
      return Color.blue.opacity(0.85)
    case .warning:
      return Color.orange.opacity(0.9)
    case .error:
      return Color.red.opacity(0.9)
    }
  }

  private struct PrimaryActionStyle: ButtonStyle {
    let style: PlaybackAlertStyle

    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .font(.subheadline.bold())
        .foregroundStyle(Color.white)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.2))
        .clipShape(Capsule())
        .opacity(configuration.isPressed ? 0.7 : 1)
    }
  }

  private struct SecondaryActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .font(.subheadline)
        .foregroundStyle(Color.white.opacity(0.9))
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
        .opacity(configuration.isPressed ? 0.7 : 1)
    }
  }
}

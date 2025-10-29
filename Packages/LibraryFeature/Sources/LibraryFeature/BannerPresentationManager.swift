//
//  BannerPresentationManager.swift
//  LibraryFeature
//
//  Created for Issue 02.2.2: EpisodeListViewModel Modularization
//  Extracts banner presentation and dismissal logic
//

import CoreModels
import Foundation
import SwiftUI

// MARK: - Protocol

/// Manages banner presentation and dismissal for episode list operations
@MainActor
public protocol BannerPresentationManaging: AnyObject {
  /// Current banner state
  var bannerState: EpisodeListBannerState? { get }
  
  /// Present a banner for a batch operation
  func presentBanner(for batchOperation: BatchOperation)
  
  /// Dismiss the current banner
  func dismissBanner()
}

// MARK: - Implementation

/// Default implementation of banner presentation management
@MainActor
public final class BannerPresentationManager: BannerPresentationManaging, ObservableObject {
  @Published public private(set) var bannerState: EpisodeListBannerState?
  
  private var bannerDismissTask: Task<Void, Never>?
  private let autoDismissDelay: TimeInterval
  private let retryHandler: (String) async -> Void
  private let undoHandler: (String) async -> Void
  
  public init(
    autoDismissDelay: TimeInterval = 5.0,
    retryHandler: @escaping (String) async -> Void,
    undoHandler: @escaping (String) async -> Void
  ) {
    self.autoDismissDelay = autoDismissDelay
    self.retryHandler = retryHandler
    self.undoHandler = undoHandler
  }
  
  public func presentBanner(for batchOperation: BatchOperation) {
    guard let banner = makeBannerState(for: batchOperation) else { return }
    
    bannerState = banner
    bannerDismissTask?.cancel()
    bannerDismissTask = Task { [weak self] in
      let delay = UInt64(self?.autoDismissDelay ?? 5.0) * 1_000_000_000
      try? await Task.sleep(nanoseconds: delay)
      await MainActor.run {
        guard let self else { return }
        if self.bannerState?.title == banner.title && self.bannerState?.subtitle == banner.subtitle {
          self.bannerState = nil
        }
      }
    }
  }
  
  public func dismissBanner() {
    bannerDismissTask?.cancel()
    bannerDismissTask = nil
    bannerState = nil
  }
  
  // MARK: - Private Methods
  
  private func makeBannerState(for batchOperation: BatchOperation) -> EpisodeListBannerState? {
    let succeeded = batchOperation.completedCount
    let failed = batchOperation.failedCount
    let total = batchOperation.totalCount
    
    if total == 0 {
      return nil
    }
    
    let title: String
    switch batchOperation.status {
    case .failed:
      title = "\(batchOperation.operationType.displayName) Failed"
    default:
      title = "\(batchOperation.operationType.displayName) Complete"
    }
    
    var subtitleParts: [String] = []
    if succeeded > 0 {
      subtitleParts.append("\(succeeded) succeeded")
    }
    if failed > 0 {
      subtitleParts.append("\(failed) failed")
    }
    if subtitleParts.isEmpty {
      subtitleParts.append("No changes applied")
    }
    let subtitle = subtitleParts.joined(separator: " • ")
    
    let style: EpisodeListBannerState.Style =
      (failed > 0 || batchOperation.status == .failed) ? .failure : .success
    let operationID = batchOperation.id
    
    let retryAction: (() -> Void)? =
      failed > 0
      ? { [weak self] in
        guard let self else { return }
        Task { await self.retryHandler(operationID) }
      } : nil
    
    let undoAction: (() -> Void)? =
      batchOperation.operationType.isReversible
      ? { [weak self] in
        guard let self else { return }
        Task { await self.undoHandler(operationID) }
      } : nil
    
    return EpisodeListBannerState(
      title: title,
      subtitle: subtitle,
      style: style,
      retry: retryAction,
      undo: undoAction
    )
  }
}

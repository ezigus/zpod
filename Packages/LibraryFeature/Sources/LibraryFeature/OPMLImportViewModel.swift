import CoreModels
import FeedParsing
import Foundation

// MARK: - Result Wrapper

/// Identifiable wrapper around OPMLImportResult so it can be used with sheet(item:).
struct OPMLImportResultItem: Identifiable {
    let id = UUID()
    let result: OPMLImportResult
}

// MARK: - View Model

@MainActor
final class OPMLImportViewModel: ObservableObject {
    @Published var importResultItem: OPMLImportResultItem? = nil
    @Published var isImporting: Bool = false
    @Published var errorMessage: String? = nil

    var showError: Bool { errorMessage != nil }

    private let importService: OPMLImportService
    private(set) var importTask: Task<Void, Never>?

    init(importService: OPMLImportService) {
        self.importService = importService
    }

    /// Handles the result from a file picker.
    ///
    /// Failure cases are resolved synchronously. Success cases set `isImporting = true`
    /// immediately (preventing re-entrant calls) and spin up an internal Task.
    /// Returns the Task so callers (e.g. unit tests) can `await` completion.
    @discardableResult
    func handleFileSelection(_ result: Result<[URL], Error>) -> Task<Void, Never>? {
        // Failure is handled synchronously — no import task needed.
        if case .failure(let error) = result {
            errorMessage = error.localizedDescription
            return nil
        }
        // Guard against re-entrant calls while an import is already in flight.
        // isImporting is set to true here (synchronously on MainActor) so a second
        // call racing before the Task body runs will correctly see the flag.
        guard !isImporting else { return nil }
        isImporting = true
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performImport(result)
        }
        importTask = task
        return task
    }

    /// Cancels an in-progress import and resets loading state.
    func cancelImport() {
        importTask?.cancel()
        importTask = nil
        isImporting = false
    }

    // MARK: - Private

    private func performImport(_ result: Result<[URL], Error>) async {
        defer { isImporting = false }
        guard case .success(let urls) = result, let url = urls.first else {
            errorMessage = "No file was selected."
            return
        }
        // .fileImporter returns a security-scoped URL. Start access before reading;
        // startAccessingSecurityScopedResource() returns false for non-security-scoped
        // URLs (e.g. in tests), which is fine — the resource is still readable.
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        do {
            guard !Task.isCancelled else { return }
            let opmlResult = try await importService.importSubscriptions(from: url)
            guard !Task.isCancelled else { return }
            importResultItem = OPMLImportResultItem(result: opmlResult)
        } catch OPMLImportService.Error.invalidOPML {
            errorMessage = "The selected file is not a valid OPML file."
        } catch OPMLImportService.Error.noFeedsFound {
            errorMessage = "No podcast feeds were found in the selected file."
        } catch {
            if !Task.isCancelled {
                errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

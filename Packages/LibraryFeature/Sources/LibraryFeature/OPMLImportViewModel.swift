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

    init(importService: OPMLImportService) {
        self.importService = importService
    }

    func handleFileSelection(_ result: Result<[URL], Error>) async {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else {
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
            isImporting = true
            defer { isImporting = false }
            do {
                let opmlResult = try await importService.importSubscriptions(from: url)
                importResultItem = OPMLImportResultItem(result: opmlResult)
            } catch OPMLImportService.Error.invalidOPML {
                errorMessage = "The selected file is not a valid OPML file."
            } catch OPMLImportService.Error.noFeedsFound {
                errorMessage = "No podcast feeds were found in the selected file."
            } catch {
                errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

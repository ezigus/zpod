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
            // .fileImporter returns a security-scoped URL. We must start access before
            // reading the file and stop it when we are done (even if an error is thrown).
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
            } catch OPMLImportService.Error.allFeedsFailed {
                errorMessage = "All feeds in the OPML file failed to import."
            } catch {
                errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
    }
}

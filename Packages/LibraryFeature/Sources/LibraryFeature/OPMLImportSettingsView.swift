import CoreModels
import SwiftUI
import UniformTypeIdentifiers

struct OPMLImportSettingsView: View {
    @StateObject var viewModel: OPMLImportViewModel
    @State private var isPickerPresented = false

    var body: some View {
        List {
            Section {
                Button {
                    isPickerPresented = true
                } label: {
                    Label("Import Subscriptions (OPML)", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("Settings.ImportOPML")
                .disabled(viewModel.isImporting)
            } footer: {
                Text("Select an OPML file to import podcast subscriptions from another app.")
            }

            if viewModel.isImporting {
                Section {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Importing…")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Cancel") {
                            viewModel.cancelImport()
                        }
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("Settings.ImportOPML.Cancel")
                    }
                }
            }
        }
        .navigationTitle("OPML Import")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear {
#if DEBUG
            // Launch-environment hook for UI testing only.
            // UITEST_OPML_MOCK=success  → immediately show a mock success result sheet.
            // UITEST_OPML_MOCK=error_invalid → immediately show the invalid-OPML error alert.
            // UITEST_OPML_MOCK=error_no_feeds → show the no-feeds-found error alert.
            // In production the key is absent and this block is a no-op.
            let mock = ProcessInfo.processInfo.environment["UITEST_OPML_MOCK"]
            switch mock {
            case "success":
                // Defer to the next run-loop tick so the NavigationLink push animation has
                // fully settled before SwiftUI is asked to present the sheet.  Presenting a
                // sheet(item:) directly inside onAppear can race with the incoming navigation
                // animation and silently skip the presentation.
                Task { @MainActor in
                    viewModel.importResultItem = OPMLImportResultItem(
                        result: OPMLImportResult(
                            successfulFeeds: ["https://example.com/feed1.rss", "https://example.com/feed2.rss"],
                            failedFeeds: [],
                            totalFeeds: 2
                        )
                    )
                }
            case "error_invalid":
                viewModel.errorMessage = "The selected file is not a valid OPML file."
            case "error_no_feeds":
                viewModel.errorMessage = "No podcast feeds were found in the selected file."
            default:
                break
            }
#endif
        }
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [.xml]
        ) { result in
            // .fileImporter with single-file selection returns Result<URL, Error>.
            // Lift it to Result<[URL], Error> to match the view model's API.
            // handleFileSelection is synchronous — it creates its own internal Task.
            let lifted: Result<[URL], Error> = result.map { [$0] }
            viewModel.handleFileSelection(lifted)
        }
        .sheet(item: $viewModel.importResultItem) { item in
            OPMLImportResultView(result: item)
        }
        .alert("Import Error", isPresented: .init(
            get: { viewModel.showError },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

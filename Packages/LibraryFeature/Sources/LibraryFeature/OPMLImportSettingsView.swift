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
                    }
                }
            }
        }
        .navigationTitle("OPML Import")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .fileImporter(
            isPresented: $isPickerPresented,
            allowedContentTypes: [.xml]
        ) { result in
            // .fileImporter with single-file selection returns Result<URL, Error>.
            // Lift it to Result<[URL], Error> to match the view model's API.
            let lifted: Result<[URL], Error> = result.map { [$0] }
            Task {
                await viewModel.handleFileSelection(lifted)
            }
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

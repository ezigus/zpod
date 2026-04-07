import CoreModels
import SwiftUI

struct OPMLImportResultView: View {
    let result: OPMLImportResultItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: result.result.isCompleteSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(result.result.isCompleteSuccess ? .green : .orange)
                        Text("Imported \(result.result.successfulFeeds.count) of \(result.result.totalFeeds) podcasts")
                            .font(.headline)
                    }
                }

                if !result.result.failedFeeds.isEmpty {
                    Section("Failed Feeds") {
                        ForEach(result.result.failedFeeds, id: \.url) { failed in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(failed.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(failed.error)
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .accessibilityIdentifier("Settings.ImportOPML.Result")
            .navigationTitle("Import Result")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

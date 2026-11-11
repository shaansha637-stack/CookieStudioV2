import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class CookieStore: ObservableObject {
    @Published var documents: [CookieDocument] = []
    @Published var selectedDocumentID: UUID?
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var statusMessage: String?

    var selectedIndex: Int? {
        documents.firstIndex { $0.id == selectedDocumentID }
    }
    var selectedDocument: CookieDocument? {
        guard let i = selectedIndex else { return nil }
        return documents[i]
    }
    var filteredCookies: [CookieRecord] {
        guard let doc = selectedDocument else { return [] }
        guard !searchText.isEmpty else { return doc.cookies }
        return doc.cookies.filter {
            $0.domain.localizedCaseInsensitiveContains(searchText) ||
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.path.localizedCaseInsensitiveContains(searchText) ||
            $0.value.localizedCaseInsensitiveContains(searchText)
        }
    }

    func importFiles(_ urls: [URL]) {
        for url in urls {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let parsed = try BinaryCookiesCodec.decode(data)
                let backupURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("CookieStudio-Original-\(UUID().uuidString)-\(url.lastPathComponent)")
                try data.write(to: backupURL, options: .atomic)
                let doc = CookieDocument(fileName: url.lastPathComponent,
                                         cookies: parsed.cookies,
                                         originalData: data,
                                         pageCount: parsed.pageCount)
                documents.append(doc)
                selectedDocumentID = doc.id
                statusMessage = "Imported \(url.lastPathComponent) · \(parsed.cookies.count) cookies"
            } catch {
                errorMessage = "\(url.lastPathComponent): \(error.localizedDescription)"
                showError = true
            }
        }
    }

    func addCookie() {
        guard let i = selectedIndex else { return }
        documents[i].cookies.insert(.blank(), at: 0)
        statusMessage = "New cookie added"
    }
    func deleteCookie(id: UUID) {
        guard let i = selectedIndex else { return }
        documents[i].cookies.removeAll { $0.id == id }
        statusMessage = "Cookie deleted"
    }
    func updateCookie(_ cookie: CookieRecord) {
        guard let i = selectedIndex,
              let j = documents[i].cookies.firstIndex(where: { $0.id == cookie.id }) else { return }
        documents[i].cookies[j] = cookie
        statusMessage = "Cookie saved"
    }
    func exportBinary() -> URL? {
        guard let doc = selectedDocument else { return nil }
        do {
            let data = try BinaryCookiesCodec.encode(doc.cookies)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(doc.fileName.replacingOccurrences(of: ".binarycookies", with: "") + "-edited.binarycookies")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }
    func exportJSON() -> URL? {
        guard let doc = selectedDocument else { return nil }
        do {
            let data = try JSONEncoder.pretty.encode(doc.cookies)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("CookieStudio-Cookies.json")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

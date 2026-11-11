import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = CookieStore()
    @State private var showImporter = false
    @State private var exportURL: URL?
    @State private var exportType: ExportKind = .binary
    @State private var showExporter = false
    @State private var selectedCookie: CookieRecord?
    @State private var showEditor = false
    @State private var showHex = false
    @State private var showJSON = false

    private var secureCount: Int {
        store.selectedDocument?.cookies.filter { $0.flags & 1 != 0 }.count ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppBackground()
                VStack(spacing: 14) {
                    header
                    if store.documents.isEmpty {
                        emptyState
                    } else {
                        documentPicker
                        summary
                        searchBar
                        cookieList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                toast
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.statusMessage)
            .task(id: store.statusMessage) {
                guard store.statusMessage != nil else { return }
                do { try await Task.sleep(nanoseconds: 2_500_000_000) } catch { return }
                store.statusMessage = nil
            }
            .safeAreaInset(edge: .bottom) {
                if !store.documents.isEmpty { actionBar }
            }
            .navigationBarHidden(true)
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.data, .item],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): store.importFiles(urls)
                case .failure(let error):
                    store.errorMessage = error.localizedDescription
                    store.showError = true
                }
            }
            .sheet(isPresented: $showEditor) {
                if let cookie = selectedCookie {
                    CookieEditorView(cookie: cookie) { store.updateCookie($0) }
                }
            }
            .sheet(isPresented: $showHex) {
                if let doc = store.selectedDocument { HexViewer(data: doc.originalData, title: doc.fileName) }
            }
            .sheet(isPresented: $showJSON) {
                if let doc = store.selectedDocument { JSONViewer(cookies: doc.cookies) }
            }
            .fileExporter(isPresented: $showExporter,
                          document: ExportFile(data: exportURL.flatMap { try? Data(contentsOf: $0) } ?? Data()),
                          contentType: exportType == .binary ? .data : .json,
                          defaultFilename: exportURL?.lastPathComponent ?? "CookieStudio-export") { result in
                switch result {
                case .success:
                    store.statusMessage = "Export complete"
                case .failure(let error):
                    store.errorMessage = error.localizedDescription
                    store.showError = true
                }
            }
            .alert("Cookie Studio", isPresented: $store.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "An unknown error occurred.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentGradient)
                Image(systemName: "curlybraces")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .shadow(color: Theme.coral.opacity(0.4), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("Cookie Studio")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Binary Cookies Toolkit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button { showImporter = true } label: {
                Image(systemName: "plus").font(.system(size: 17, weight: .bold))
            }
            .buttonStyle(CircleIconButtonStyle())
            .accessibilityLabel("Import cookies")
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(Theme.amber.opacity(0.30)).frame(width: 150, height: 150).blur(radius: 28)
                Circle().fill(Theme.card).frame(width: 116, height: 116)
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(Theme.accentGradient)
            }
            VStack(spacing: 8) {
                Text("Import Binary Cookies")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Select one or more .binarycookies files from the Files app. Everything is processed locally on this iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            Button { showImporter = true } label: {
                Label("Choose Files", systemImage: "folder.fill")
            }
            .buttonStyle(PrimaryButtonStyle())

            HStack(spacing: 8) {
                featureChip("Edit", "pencil")
                featureChip("JSON", "curlybraces")
                featureChip("Hex", "number")
                featureChip("Export", "square.and.arrow.up")
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private func featureChip(_ title: String, _ icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .glassCard(radius: 20)
    }

    // MARK: - Loaded state

    private var documentPicker: some View {
        Menu {
            ForEach(store.documents) { doc in
                Button("\(doc.fileName) · \(doc.cookies.count)") {
                    store.selectedDocumentID = doc.id
                    store.searchText = ""
                }
            }
            Divider()
            Button { showImporter = true } label: {
                Label("Import More Files", systemImage: "plus")
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text.fill").foregroundStyle(Theme.accentGradient)
                Text(store.selectedDocument?.fileName ?? "Select file")
                    .lineLimit(1)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(store.documents.count) files").font(.caption).foregroundStyle(.secondary)
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .padding(14)
            .glassCard()
        }
    }

    private var summary: some View {
        HStack(spacing: 10) {
            metric("COOKIES", "\(store.selectedDocument?.cookies.count ?? 0)", "list.bullet", Theme.amber)
            metric("PAGES", "\(store.selectedDocument?.pageCount ?? 0)", "square.stack.3d.up", Theme.violet)
            metric("SECURE", "\(secureCount)", "lock.fill", Theme.green)
        }
    }

    private func metric(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(radius: 14)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search domain, name, path, value", text: $store.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !store.searchText.isEmpty {
                Button { store.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .glassCard(radius: 14)
    }

    private var cookieList: some View {
        List {
            ForEach(store.filteredCookies) { cookie in
                Button {
                    selectedCookie = cookie
                    showEditor = true
                } label: {
                    cookieRow(cookie)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
                .swipeActions {
                    Button(role: .destructive) { store.deleteCookie(id: cookie.id) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if store.filteredCookies.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(.secondary)
                    Text("No Cookies").font(.headline).foregroundStyle(.white)
                    Text("No matching records.").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func cookieRow(_ cookie: CookieRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.amber.opacity(0.15))
                Image(systemName: "globe").foregroundStyle(Theme.amber)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(cookie.name.isEmpty ? "(no name)" : cookie.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(cookie.domain.isEmpty ? "(no domain)" : cookie.domain)
                    .font(.caption)
                    .foregroundStyle(Theme.cyan)
                    .lineLimit(1)
                Text(cookie.value.isEmpty ? "(empty value)" : cookie.value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    chip(cookie.path, Theme.violet)
                    if cookie.flags & 1 != 0 { chip("Secure", Theme.green) }
                    if cookie.flags & 4 != 0 { chip("HttpOnly", Theme.amber) }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 12)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }

    // MARK: - Bottom action bar

    private var actionBar: some View {
        HStack(spacing: 6) {
            Button {
                store.addCookie()
                if let first = store.selectedDocument?.cookies.first {
                    selectedCookie = first
                    showEditor = true
                }
            } label: {
                barLabel("Add", "plus.circle.fill")
                    .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button { showJSON = true } label: { barLabel("JSON", "curlybraces") }
                .buttonStyle(.plain)

            Button { showHex = true } label: { barLabel("Hex", "number") }
                .buttonStyle(.plain)

            Menu {
                Button {
                    if let url = store.exportBinary() { exportURL = url; exportType = .binary; showExporter = true }
                } label: { Label("Export Binary", systemImage: "square.and.arrow.up") }
                Button {
                    if let url = store.exportJSON() { exportURL = url; exportType = .json; showExporter = true }
                } label: { Label("Export JSON", systemImage: "doc.text") }
            } label: {
                barLabel("Export", "square.and.arrow.up")
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func barLabel(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
            Text(title).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Toast

    @ViewBuilder
    private var toast: some View {
        if let message = store.statusMessage {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
                .padding(.top, 64)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

enum ExportKind { case binary, json }

struct ExportFile: FileDocument {
    static var readableContentTypes: [UTType] { [.data, .json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

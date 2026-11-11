import SwiftUI

struct CookieEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var cookie: CookieRecord
    let onSave: (CookieRecord) -> Void

    init(cookie: CookieRecord, onSave: @escaping (CookieRecord) -> Void) {
        _cookie = State(initialValue: cookie)
        self.onSave = onSave
    }

    private func flag(_ mask: UInt32) -> Binding<Bool> {
        Binding(
            get: { cookie.flags & mask != 0 },
            set: { isOn in
                if isOn { cookie.flags |= mask } else { cookie.flags &= ~mask }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    field("Domain", icon: "globe", text: $cookie.domain)
                    field("Name", icon: "tag", text: $cookie.name)
                    field("Path", icon: "arrow.triangle.branch", text: $cookie.path)
                }
                .listRowBackground(Theme.card)

                Section("Value") {
                    TextEditor(text: $cookie.value)
                        .font(.system(.footnote, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 110)
                }
                .listRowBackground(Theme.card)

                Section("Dates") {
                    DatePicker("Expires", selection: $cookie.expires)
                    DatePicker("Created", selection: $cookie.created)
                }
                .listRowBackground(Theme.card)

                Section("Flags") {
                    Toggle("Secure", isOn: flag(0x1))
                    Toggle("HttpOnly", isOn: flag(0x4))
                    TextField("Raw flags (UInt32)", value: $cookie.flags, format: .number)
                        .keyboardType(.numberPad)
                    Text("Secure and HttpOnly toggle bits of the raw 32-bit flags value stored in the binary record.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Theme.card)
            }
            .tint(Theme.amber)
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Edit Cookie")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(cookie); dismiss() }.fontWeight(.bold)
                }
            }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }

    private func field(_ title: String, icon: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.amber).frame(width: 22)
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }
}

import SwiftUI
import UIKit

struct JSONViewer: View {
    let cookies: [CookieRecord]
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(cookies) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal]) {
                Text(json)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .glassCard()
                    .padding()
                    .textSelection(.enabled)
            }
            .background(AppBackground())
            .navigationTitle("JSON Viewer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        UIPasteboard.general.string = json
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }
}

struct HexViewer: View {
    let data: Data
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    private var lines: [String] {
        stride(from: 0, to: data.count, by: 16).map { start in
            let end = min(start + 16, data.count)
            let slice = data[start..<end]
            let hex = slice.map { String(format: "%02X", $0) }.joined(separator: " ")
            let ascii = slice.map { byte -> Character in
                (byte >= 32 && byte <= 126) ? Character(UnicodeScalar(byte)) : "."
            }
            return String(format: "%08X", start) + "  " + hex.padding(toLength: 47, withPad: " ", startingAt: 0) + "  " + String(ascii)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(title) · \(data.count) BYTES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.amber)
                        .padding(.bottom, 8)
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Theme.cyan)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .glassCard()
                .padding()
            }
            .background(AppBackground())
            .navigationTitle("Raw Hex")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        UIPasteboard.general.string = lines.joined(separator: "\n")
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.fontWeight(.bold) }
            }
        }
        .tint(Theme.amber)
        .preferredColorScheme(.dark)
    }
}

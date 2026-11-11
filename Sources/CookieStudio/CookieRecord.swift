import Foundation

struct CookieRecord: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var flags: UInt32 = 0
    var domain: String
    var name: String
    var path: String
    var value: String
    var expires: Date
    var created: Date

    static func blank() -> CookieRecord {
        CookieRecord(
            domain: "",
            name: "",
            path: "/",
            value: "",
            expires: Date().addingTimeInterval(60 * 60 * 24 * 30),
            created: Date()
        )
    }
}

struct CookieDocument: Identifiable {
    let id = UUID()
    var fileName: String
    var cookies: [CookieRecord]
    var originalData: Data
    var pageCount: Int
}

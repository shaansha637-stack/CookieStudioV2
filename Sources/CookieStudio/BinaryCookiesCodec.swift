import Foundation

enum BinaryCookiesError: LocalizedError {
    case badMagic
    case truncated
    case invalidPageCount
    case invalidPageSize
    case invalidCookieCount
    case invalidRecord
    case invalidStringOffset
    case tooManyCookies

    var errorDescription: String? {
        switch self {
        case .badMagic: return "This file does not have the Apple 'cook' Binary Cookies signature."
        case .truncated: return "The file is truncated or contains an out-of-range offset."
        case .invalidPageCount: return "The page count is invalid."
        case .invalidPageSize: return "A cookie page has an invalid size."
        case .invalidCookieCount: return "A cookie page has an invalid cookie count."
        case .invalidRecord: return "A cookie record is malformed."
        case .invalidStringOffset: return "A cookie string offset is invalid."
        case .tooManyCookies: return "The file contains too many cookies to safely process."
        }
    }
}

enum BinaryCookiesCodec {
    private static let maxCookies = 100_000
    private static let maxPageBytes = 16 * 1024 * 1024
    private static let macEpoch: TimeInterval = 978_307_200

    static func decode(_ data: Data) throws -> (cookies: [CookieRecord], pageCount: Int) {
        guard data.count >= 8 else { throw BinaryCookiesError.truncated }
        guard data.prefix(4) == Data([0x63, 0x6f, 0x6f, 0x6b]) else {
            throw BinaryCookiesError.badMagic
        }

        let pageCount = Int(try readBE32(data, 4))
        guard pageCount > 0, pageCount <= 4096 else { throw BinaryCookiesError.invalidPageCount }
        guard data.count >= 8 + pageCount * 4 else { throw BinaryCookiesError.truncated }

        var pageSizes: [Int] = []
        for i in 0..<pageCount {
            let size = Int(try readBE32(data, 8 + i * 4))
            guard size >= 8, size <= maxPageBytes else { throw BinaryCookiesError.invalidPageSize }
            pageSizes.append(size)
        }

        var cursor = 8 + pageCount * 4
        var result: [CookieRecord] = []
        for pageSize in pageSizes {
            guard cursor <= data.count, pageSize <= data.count - cursor else { throw BinaryCookiesError.truncated }
            let page = data.subdata(in: cursor..<(cursor + pageSize))
            let count = Int(try readLE32(page, 4))
            guard count >= 0, count <= maxCookies, result.count + count <= maxCookies else {
                throw BinaryCookiesError.invalidCookieCount
            }
            guard 8 + count * 4 <= page.count else { throw BinaryCookiesError.truncated }

            for i in 0..<count {
                let recordOffset = Int(try readLE32(page, 8 + i * 4))
                result.append(try decodeRecord(page, at: recordOffset))
            }
            cursor += pageSize
        }
        return (result, pageCount)
    }

    private static func decodeRecord(_ page: Data, at offset: Int) throws -> CookieRecord {
        guard offset >= 0, offset + cookieHeaderSize <= page.count else { throw BinaryCookiesError.invalidRecord }
        let recordSize = Int(try readLE32(page, offset))
        guard recordSize >= cookieHeaderSize, recordSize <= page.count - offset else {
            throw BinaryCookiesError.invalidRecord
        }
        let flags = try readLE32(page, offset + 8)
        let domainOffset = Int(try readLE32(page, offset + 16))
        let nameOffset = Int(try readLE32(page, offset + 20))
        let pathOffset = Int(try readLE32(page, offset + 24))
        let valueOffset = Int(try readLE32(page, offset + 28))
        let expiry = try readLEDouble(page, offset + 32)
        let creation = try readLEDouble(page, offset + 40)

        func stringAt(_ relative: Int) throws -> String {
            guard relative >= cookieHeaderSize, relative < recordSize else {
                throw BinaryCookiesError.invalidStringOffset
            }
            let start = offset + relative
            let endLimit = offset + recordSize
            var end = start
            while end < endLimit && page[end] != 0 { end += 1 }
            guard end < endLimit else { throw BinaryCookiesError.invalidStringOffset }
            let bytes = page.subdata(in: start..<end)
            guard let string = String(data: bytes, encoding: .utf8) else {
                return String(decoding: bytes, as: UTF8.self)
            }
            return string
        }

        return CookieRecord(
            flags: flags,
            domain: try stringAt(domainOffset),
            name: try stringAt(nameOffset),
            path: try stringAt(pathOffset),
            value: try stringAt(valueOffset),
            expires: Date(timeIntervalSinceReferenceDate: expiry),
            created: Date(timeIntervalSinceReferenceDate: creation)
        )
    }

    static func encode(_ cookies: [CookieRecord]) throws -> Data {
        guard cookies.count <= maxCookies else { throw BinaryCookiesError.tooManyCookies }
        let pageCapacity = 200
        let chunks: [[CookieRecord]] = stride(from: 0, to: max(cookies.count, 1), by: pageCapacity).map {
            Array(cookies.dropFirst($0).prefix(pageCapacity))
        }

        var pages: [Data] = []
        for chunk in chunks {
            var records: [Data] = []
            for cookie in chunk { records.append(try encodeRecord(cookie)) }

            var page = Data([0x00, 0x00, 0x01, 0x00])
            page.appendLE32(UInt32(chunk.count))
            let offsetTableStart = page.count
            page.append(Data(repeating: 0, count: chunk.count * 4))

            for (index, record) in records.enumerated() {
                page.replaceLE32(at: offsetTableStart + index * 4, with: UInt32(page.count))
                page.append(record)
            }
            pages.append(page)
        }

        var output = Data([0x63, 0x6f, 0x6f, 0x6b])
        output.appendBE32(UInt32(pages.count))
        for page in pages { output.appendBE32(UInt32(page.count)) }
        for page in pages { output.append(page) }
        return output
    }

    private static let cookieHeaderSize = 48

    private static func encodeRecord(_ cookie: CookieRecord) throws -> Data {
        let strings = [cookie.domain, cookie.name, cookie.path, cookie.value]
        var record = Data(repeating: 0, count: cookieHeaderSize)
        var offsets: [UInt32] = []
        for string in strings {
            offsets.append(UInt32(record.count))
            record.append(contentsOf: string.utf8)
            record.append(0)
        }
        record.replaceLE32(at: 0, with: UInt32(record.count))
        record.replaceLE32(at: 8, with: cookie.flags)
        for (i, value) in offsets.enumerated() {
            record.replaceLE32(at: 16 + i * 4, with: value)
        }
        record.replaceLEDouble(at: 32, with: cookie.expires.timeIntervalSinceReferenceDate)
        record.replaceLEDouble(at: 40, with: cookie.created.timeIntervalSinceReferenceDate)
        return record
    }

    private static func readBE32(_ d: Data, _ o: Int) throws -> UInt32 {
        guard o >= 0, o + 4 <= d.count else { throw BinaryCookiesError.truncated }
        return (UInt32(d[o]) << 24) | (UInt32(d[o+1]) << 16) | (UInt32(d[o+2]) << 8) | UInt32(d[o+3])
    }
    private static func readLE32(_ d: Data, _ o: Int) throws -> UInt32 {
        guard o >= 0, o + 4 <= d.count else { throw BinaryCookiesError.truncated }
        return UInt32(d[o]) | (UInt32(d[o+1]) << 8) | (UInt32(d[o+2]) << 16) | (UInt32(d[o+3]) << 24)
    }
    private static func readLEDouble(_ d: Data, _ o: Int) throws -> Double {
        let bits = try readLE64(d, o)
        return Double(bitPattern: bits)
    }
    private static func readLE64(_ d: Data, _ o: Int) throws -> UInt64 {
        guard o >= 0, o + 8 <= d.count else { throw BinaryCookiesError.truncated }
        var v: UInt64 = 0
        for i in 0..<8 { v |= UInt64(d[o+i]) << (8 * i) }
        return v
    }
}

private extension Data {
    mutating func appendLE32(_ value: UInt32) {
        append(UInt8(value & 0xff)); append(UInt8((value >> 8) & 0xff))
        append(UInt8((value >> 16) & 0xff)); append(UInt8((value >> 24) & 0xff))
    }
    mutating func appendBE32(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff)); append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff)); append(UInt8(value & 0xff))
    }
    mutating func replaceLE32(at offset: Int, with value: UInt32) {
        guard offset >= 0, offset + 4 <= count else { return }
        self[offset] = UInt8(value & 0xff)
        self[offset+1] = UInt8((value >> 8) & 0xff)
        self[offset+2] = UInt8((value >> 16) & 0xff)
        self[offset+3] = UInt8((value >> 24) & 0xff)
    }
    mutating func replaceLEDouble(at offset: Int, with value: Double) {
        let bits = value.bitPattern
        guard offset >= 0, offset + 8 <= count else { return }
        for i in 0..<8 { self[offset+i] = UInt8((bits >> (8 * i)) & 0xff) }
    }
}

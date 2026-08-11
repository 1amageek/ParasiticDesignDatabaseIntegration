import CircuiteFoundation
import DatabaseTypes
import DatabaseTypesFoundation
import Foundation

public struct ParasiticDatabaseCanonicalDocument: Sendable {
    public static let defaultPageByteCount = 64 * 1_024

    public let state: ParasiticDatabaseState
    public let canonicalData: Data
    public let facetRootDigest: ContentDigest
    public let pages: [ParasiticDatabaseFacetPage]

    public init(
        state: ParasiticDatabaseState,
        pageByteCount: Int = Self.defaultPageByteCount
    ) throws(ParasiticDatabaseSchemaError) {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let data = try ParasiticDatabaseCanonicalCodec.encode(state)
        let digest: ContentDigest
        do {
            digest = try ParasiticDatabaseDigesting.sha256(Array(data))
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
        let pageCount = max(1, (data.count + pageByteCount - 1) / pageByteCount)
        guard let persistedPageCount = UInt64(exactly: pageCount),
              let persistedByteCount = UInt64(exactly: data.count) else {
            throw .pageCountOverflow
        }
        let owner = ByteString(retaining: data)
        var pages: [ParasiticDatabaseFacetPage] = []
        pages.reserveCapacity(pageCount)
        for index in 0..<pageCount {
            let lower = index * pageByteCount
            let upper = min(data.count, lower + pageByteCount)
            guard let ordinal = UInt64(exactly: index) else {
                throw .pageCountOverflow
            }
            pages.append(
                ParasiticDatabaseFacetPage(
                    id: Self.pageID(ordinal),
                    facetID: ParasiticDatabaseFacet.parasitics.rawValue,
                    ordinal: ordinal,
                    pageCount: persistedPageCount,
                    documentByteCount: persistedByteCount,
                    documentDigest: digest.hexadecimalValue,
                    payload: owner[lower..<upper]
                )
            )
        }
        self.state = state
        canonicalData = data
        facetRootDigest = digest
        self.pages = pages
    }

    public static func pageCount(
        forByteCount byteCount: Int,
        pageByteCount: Int = defaultPageByteCount
    ) throws(ParasiticDatabaseSchemaError) -> UInt64 {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let count = max(1, (byteCount + pageByteCount - 1) / pageByteCount)
        guard let result = UInt64(exactly: count) else {
            throw .pageCountOverflow
        }
        return result
    }

    /// Materializes pages from a Runtime-authenticated validation capsule.
    /// This method intentionally does not repeat domain semantic validation.
    public static func materializeValidated(
        canonicalData: Data,
        pageByteCount: Int = defaultPageByteCount
    ) throws(ParasiticDatabaseSchemaError) -> (
        facetRootDigest: ContentDigest,
        pages: [ParasiticDatabaseFacetPage]
    ) {
        guard pageByteCount > 0 else {
            throw .invalidPageByteCount(pageByteCount)
        }
        let digest: ContentDigest
        do {
            digest = try ParasiticDatabaseDigesting.sha256(Array(canonicalData))
        } catch {
            throw .encodingFailed(reason: String(describing: error))
        }
        let pageCount = max(
            1,
            (canonicalData.count + pageByteCount - 1) / pageByteCount
        )
        guard let persistedPageCount = UInt64(exactly: pageCount),
              let persistedByteCount = UInt64(exactly: canonicalData.count) else {
            throw .pageCountOverflow
        }
        let owner = ByteString(retaining: canonicalData)
        var pages: [ParasiticDatabaseFacetPage] = []
        pages.reserveCapacity(pageCount)
        for index in 0..<pageCount {
            guard let ordinal = UInt64(exactly: index) else {
                throw .pageCountOverflow
            }
            let lower = index * pageByteCount
            let upper = min(canonicalData.count, lower + pageByteCount)
            pages.append(
                ParasiticDatabaseFacetPage(
                    id: pageID(ordinal),
                    facetID: ParasiticDatabaseFacet.parasitics.rawValue,
                    ordinal: ordinal,
                    pageCount: persistedPageCount,
                    documentByteCount: persistedByteCount,
                    documentDigest: digest.hexadecimalValue,
                    payload: owner[lower..<upper]
                )
            )
        }
        return (digest, pages)
    }

    private static func pageID(_ ordinal: UInt64) -> String {
        let value = String(ordinal)
        return String(repeating: "0", count: 20 - value.count) + value
    }
}

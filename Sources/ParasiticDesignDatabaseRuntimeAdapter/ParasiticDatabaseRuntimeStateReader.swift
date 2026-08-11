import CircuiteFoundation
import CircuiteFoundationCrypto
import Database
import DatabaseTypesFoundation
import DesignDatabaseRuntime
import Foundation
import ParasiticDesignDatabaseSchema

public struct ParasiticDatabaseRuntimeStateReader: Sendable {
    public init() {}

    public func read(
        expectedRoot: ContentDigest,
        from reads: DesignDatabaseRuntimeReadSnapshot,
        budget: ParasiticDatabaseReadBudget
    ) async throws -> ParasiticDatabaseState {
        var partition = DirectoryPath<ParasiticDatabaseFacetPage>()
        partition.set(
            ParasiticDatabaseFacetPage.fields.facetID,
            to: ParasiticDatabaseFacet.parasitics.rawValue
        )
        partition.set(
            ParasiticDatabaseFacetPage.fields.documentDigest,
            to: expectedRoot.hexadecimalValue
        )
        var pages: [ParasiticDatabaseFacetPage] = []
        pages.reserveCapacity(min(budget.maximumPageCount, budget.pageFetchLimit))
        var continuation: DatabaseScanContinuation?
        repeat {
            let page = try await reads.scan(
                ParasiticDatabaseFacetPage.self,
                in: partition,
                after: continuation,
                limit: budget.pageFetchLimit
            )
            pages.append(contentsOf: page.items)
            guard pages.count <= budget.maximumPageCount else {
                throw ParasiticDatabaseReadError.pageBudgetExceeded(
                    limit: budget.maximumPageCount
                )
            }
            continuation = page.continuation
        } while continuation != nil
        return try decode(pages: pages, expectedRoot: expectedRoot)
    }

    private func decode(
        pages: [ParasiticDatabaseFacetPage],
        expectedRoot: ContentDigest
    ) throws -> ParasiticDatabaseState {
        guard let first = pages.first else {
            throw ParasiticDatabaseReadError.missingFacetPages
        }
        let ordered = pages.sorted { $0.ordinal < $1.ordinal }
        guard first.pageCount == UInt64(ordered.count),
              ordered.allSatisfy({ page in
                  page.facetID == ParasiticDatabaseFacet.parasitics.rawValue
                      && page.pageCount == first.pageCount
                      && page.documentByteCount == first.documentByteCount
                      && page.documentDigest == first.documentDigest
              }) else {
            throw ParasiticDatabaseReadError.inconsistentPageMetadata
        }
        for (index, page) in ordered.enumerated() {
            guard page.ordinal == UInt64(index) else {
                throw ParasiticDatabaseReadError.nonContiguousPages
            }
        }
        guard let capacity = Int(exactly: first.documentByteCount) else {
            throw ParasiticDatabaseReadError.inconsistentPageMetadata
        }
        var data = Data()
        data.reserveCapacity(capacity)
        for page in ordered {
            page.payload.withUnsafeBytes { bytes in
                data.append(bytes.bindMemory(to: UInt8.self))
            }
        }
        guard let actualByteCount = UInt64(exactly: data.count),
              actualByteCount == first.documentByteCount else {
            throw ParasiticDatabaseReadError.byteCountMismatch(
                expected: first.documentByteCount,
                actual: UInt64(data.count)
            )
        }
        let actualRoot = try SHA256ContentDigester().digest(data: data)
        guard actualRoot == expectedRoot else {
            throw ParasiticDatabaseReadError.facetRootMismatch(
                expected: expectedRoot,
                actual: actualRoot
            )
        }
        do {
            return try ParasiticDatabaseCanonicalCodec.decode(data)
        } catch let error {
            throw ParasiticDatabaseReadError.decodeFailed(error)
        }
    }
}

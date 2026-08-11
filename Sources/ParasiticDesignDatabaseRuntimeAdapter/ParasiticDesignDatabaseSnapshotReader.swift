import DesignDatabaseCore
import DesignDatabaseRuntime
import LayoutDesignDatabaseSchema
import ParasiticDesignDatabaseSchema
import PDKDesignDatabaseSchema

public struct ParasiticDesignDatabaseSnapshotReader:
    ParasiticDesignDatabaseReading,
    Sendable
{
    public init() {}

    public func readState(
        from snapshot: any DesignReadSnapshot,
        budget: ParasiticDatabaseReadBudget
    ) async throws -> ParasiticSnapshotState {
        let facetID = try ParasiticDatabaseFacet.parasitics.designFacetID
        guard let root = snapshot.facetRoots.first(where: {
            $0.facetID == facetID
        })?.digest else {
            return ParasiticSnapshotState(parasitics: nil, invalidation: nil)
        }
        guard let runtimeSnapshot = snapshot as? DesignDatabaseRuntimeSnapshot else {
            throw ParasiticDatabaseReadError.unsupportedSnapshotImplementation
        }
        let state = try await runtimeSnapshot.withRuntimeReads(
            maximumReadCount: try budget.runtimeReadCount
        ) { reads in
            try await ParasiticDatabaseRuntimeStateReader().read(
                expectedRoot: root,
                from: reads,
                budget: budget
            )
        }
        let invalidation = try invalidation(for: state, in: snapshot)
        return ParasiticSnapshotState(
            parasitics: state,
            invalidation: invalidation
        )
    }

    private func invalidation(
        for state: ParasiticDatabaseState,
        in snapshot: any DesignReadSnapshot
    ) throws -> ParasiticFacetInvalidation? {
        let layoutFacetID = try LayoutDatabaseFacet.layout.designFacetID
        let actualLayoutRoot = snapshot.facetRoots.first(where: {
            $0.facetID == layoutFacetID
        })?.digest
        guard actualLayoutRoot == state.sourceLayout.sourceRootDigest else {
            return ParasiticFacetInvalidation(
                observedRevision: snapshot.revision,
                expectedRootDigest: state.sourceLayout.sourceRootDigest,
                actualRootDigest: actualLayoutRoot,
                reason: actualLayoutRoot == nil
                    ? .sourceLayoutMissing
                    : .sourceLayoutRootChanged
            )
        }
        let pdkFacetID = try PDKDatabaseFacet.process.designFacetID
        let actualPDKRoot = snapshot.facetRoots.first(where: {
            $0.facetID == pdkFacetID
        })?.digest
        guard actualPDKRoot == state.sourcePDK.sourceRootDigest else {
            return ParasiticFacetInvalidation(
                observedRevision: snapshot.revision,
                expectedRootDigest: state.sourcePDK.sourceRootDigest,
                actualRootDigest: actualPDKRoot,
                reason: actualPDKRoot == nil
                    ? .sourcePDKMissing
                    : .sourcePDKRootChanged
            )
        }
        return nil
    }
}

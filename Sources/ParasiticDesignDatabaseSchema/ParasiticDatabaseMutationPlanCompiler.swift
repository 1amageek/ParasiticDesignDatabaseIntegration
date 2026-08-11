import CircuiteFoundation
import CircuiteFoundationCrypto
import DesignDatabaseCore

public struct ParasiticDatabaseMutationPlanCompiler: Sendable {
    public init() {}

    public func compile(
        _ state: ParasiticDatabaseState,
        segmentID: DesignMutationPlanSegmentID,
        databaseID: DesignDatabaseID,
        baseRevision: DesignRevisionReference,
        designSchemaBundleDigest: ContentDigest,
        dependencyRootDigest: ContentDigest,
        semanticDependencyGraphDigest: ContentDigest,
        sourceEvidenceDigest: ContentDigest
    ) throws -> DesignMutationPlan {
        let data = try ParasiticDatabaseCanonicalCodec.encode(state)
        let payload = Array(data)
        let digester = SHA256ContentDigester()
        let payloadDigest = try DesignMutationPlanDigest.payload(
            payload,
            using: digester
        )
        let writeCount = try ParasiticDatabaseCanonicalDocument.pageCount(
            forByteCount: data.count
        )
        let segment = try DesignMutationPlanSegment(
            id: segmentID,
            schemaID: try ParasiticDesignDatabaseSchema.schemaID,
            schemaVersion: .v1,
            adapterVersion: ParasiticDesignDatabaseSchema.adapterVersion,
            targetFacet: try ParasiticDatabaseFacet.parasitics.designFacetID,
            payload: payload,
            payloadDigest: payloadDigest,
            expectedWriteCount: writeCount
        )
        let budget = try DesignMutationPlanBudget(
            maximumSegmentCount: 1,
            maximumPayloadByteCount: UInt64(data.count),
            maximumPreparedWriteCount: writeCount,
            maximumValidationReadCount: 8_194
        )
        let planDigest = try DesignMutationPlanDigest.plan(
            databaseID: databaseID,
            baseRevision: baseRevision,
            designSchemaBundleDigest: designSchemaBundleDigest,
            dependencyRootDigest: dependencyRootDigest,
            semanticDependencyGraphDigest: semanticDependencyGraphDigest,
            sourceEvidenceDigest: sourceEvidenceDigest,
            budget: budget,
            segments: [segment],
            using: digester
        )
        return DesignMutationPlan(
            databaseID: databaseID,
            baseRevision: baseRevision,
            designSchemaBundleDigest: designSchemaBundleDigest,
            dependencyRootDigest: dependencyRootDigest,
            semanticDependencyGraphDigest: semanticDependencyGraphDigest,
            sourceEvidenceDigest: sourceEvidenceDigest,
            budget: budget,
            segments: [segment],
            planDigest: planDigest
        )
    }
}

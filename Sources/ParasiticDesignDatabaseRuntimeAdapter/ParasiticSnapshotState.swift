import ParasiticDesignDatabaseSchema

public struct ParasiticSnapshotState: Sendable, Hashable, Codable {
    public let parasitics: ParasiticDatabaseState?
    public let invalidation: ParasiticFacetInvalidation?

    public init(
        parasitics: ParasiticDatabaseState?,
        invalidation: ParasiticFacetInvalidation?
    ) {
        self.parasitics = parasitics
        self.invalidation = invalidation
    }

    public var isSemanticallyCurrent: Bool {
        invalidation == nil
    }
}

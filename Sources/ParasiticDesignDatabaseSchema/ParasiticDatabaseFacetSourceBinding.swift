import CircuiteFoundation

public struct ParasiticDatabaseFacetSourceBinding: Sendable, Hashable, Codable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let sourceRevision: DesignRevisionReference
    public let sourceFacet: ParasiticDatabaseFacet
    public let sourceRootDigest: ContentDigest

    public init(
        sourceRevision: DesignRevisionReference,
        sourceFacet: ParasiticDatabaseFacet = .parasitics,
        sourceRootDigest: ContentDigest
    ) throws(ParasiticDatabaseSchemaError) {
        guard sourceFacet == .parasitics else {
            throw .missingIdentity
        }
        schemaVersion = Self.currentSchemaVersion
        self.sourceRevision = sourceRevision
        self.sourceFacet = sourceFacet
        self.sourceRootDigest = sourceRootDigest
    }

    public func validate() throws(ParasiticDatabaseSchemaError) {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw .unsupportedSchemaVersion(schemaVersion)
        }
        guard sourceFacet == .parasitics else {
            throw .missingIdentity
        }
    }
}

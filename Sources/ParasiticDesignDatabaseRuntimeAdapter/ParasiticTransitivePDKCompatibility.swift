import PDKDesignDatabaseSchema

enum ParasiticTransitivePDKCompatibility {
    static func matches(
        parasitic: PDKDatabaseFacetSourceBinding,
        layout: PDKDatabaseFacetSourceBinding
    ) -> Bool {
        parasitic.sourceRevision.databaseID == layout.sourceRevision.databaseID
            && parasitic.sourceRootDigest == layout.sourceRootDigest
    }
}

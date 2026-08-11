import Database
import DesignDatabaseRuntime
import ParasiticDesignDatabaseSchema

extension ParasiticDesignDatabaseRuntimeAdapter:
    DesignDatabaseRuntimePhysicalWriteReclaimer
{
    static let physicalStorageType =
        "ParasiticDesignDatabaseSchema.ParasiticDatabaseFacetPage.v1"

    public var storageType: String { Self.physicalStorageType }

    public func deleteImmutableWrite(
        _ identity: DesignDatabaseRuntimeImmutableWriteIdentity,
        from transaction: any DatabaseTransactionWriting
    ) async throws(DesignDatabaseRuntimePhysicalWriteReclaimerError) {
        let components = try DesignDatabaseRuntimePhysicalWriteDeletion
            .requirePartitionComponents(identity, storageType: storageType, count: 2)
        var partition = DirectoryPath<ParasiticDatabaseFacetPage>()
        partition.set(ParasiticDatabaseFacetPage.fields.facetID, to: components[0])
        partition.set(ParasiticDatabaseFacetPage.fields.documentDigest, to: components[1])
        try await DesignDatabaseRuntimePhysicalWriteDeletion.delete(
            identity,
            model: ParasiticDatabaseFacetPage.self,
            identifiedBy: identity.modelID,
            in: partition,
            expectedIdentity: Self.physicalWriteIdentity,
            from: transaction
        )
    }

    static func physicalWriteIdentity(
        _ page: ParasiticDatabaseFacetPage
    ) throws(DesignDatabaseRuntimePreparedMutationError)
        -> DesignDatabaseRuntimeImmutableWriteIdentity {
        try DesignDatabaseRuntimeImmutableWriteIdentity(
            storageType: physicalStorageType,
            partitionComponents: [page.facetID, page.documentDigest],
            modelID: page.id
        )
    }
}
